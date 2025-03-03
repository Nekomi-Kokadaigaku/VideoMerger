//
//  VideoMergeModel.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//

import Foundation
import SwiftUI
import UserNotifications

/// 管理整体状态的数据模型
class VideoMergeModel: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let shouldDeleteKey = "shouldDeleteSourceFiles"
    
    /// “预计合并后大小”：在加载文件时就将所有源文件大小相加，方便提前查看。
    @Published var predictedMergedSize: Int? = nil
    
    /// 是否在合并完成后删除源文件（从 UserDefaults 加载）
    @Published var shouldDeleteSourceFiles: Bool
    
    /// 合并成功后实际输出文件大小
    @Published var mergedFileSize: Int? = nil
    
    @Published var folderURL: URL? {
        didSet {
            loadVideoFiles()
            // 如果用户未手动修改过输出路径，则自动与 folderURL 同步
            if !isOutputPathUserModified {
                outputFilePath = folderURL
            }
        }
    }
    
    @Published var outputFileName: String = "output.flv"
    
    // 标记用户是否手动修改过输出路径
    private var isOutputPathUserModified = false
    
    @Published var outputFilePath: URL? {
        didSet {
            if oldValue != outputFilePath {
                isOutputPathUserModified = true
            }
        }
    }
    
    @Published var videoFiles: [VideoFile] = []
    
    // 当前合并状态（小圆点、提示等）
    @Published var mergeStatus: MergeStatus = .idle
    
    init() {
        // 从 UserDefaults 中读取布尔值
        self.shouldDeleteSourceFiles = userDefaults.bool(forKey: shouldDeleteKey)
    }
    
    // 每当 shouldDeleteSourceFiles 变化时，写回 UserDefaults
    private func persistDeleteOption() {
        userDefaults.set(shouldDeleteSourceFiles, forKey: shouldDeleteKey)
    }
    
    /// 生成 yamdi 合并命令
    var mergeCommand: String {
        let inputs = videoFiles.map { "-i \"\($0.fileURL.path)\"" }
                               .joined(separator: " ")
        guard let outputFolder = outputFilePath else {
            return "yamdi \(inputs) -o \"./\(outputFileName)\""
        }
        let output = outputFolder.appendingPathComponent(outputFileName).path
        return "yamdi \(inputs) -o \"\(output)\""
    }
    
    /// 最终输出文件的 URL
    var outputURL: URL {
        guard let folder = outputFilePath else {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(outputFileName)
        }
        return folder.appendingPathComponent(outputFileName)
    }
    
    /// 扫描文件夹内的 .flv 文件并加载到列表
    func loadVideoFiles() {
        guard let folder = folderURL else {
            videoFiles = []
            predictedMergedSize = nil
            return
        }
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            let flvFiles = fileURLs.filter { $0.pathExtension.lowercased() == "flv" }
            self.videoFiles = flvFiles.map { VideoFile(fileURL: $0) }
            
            // 按时间戳排序
            self.videoFiles.sort { $0.timestamp < $1.timestamp }
            
            // 重新计算“预计合并后大小” = 所有源文件大小之和
            let totalSize = self.videoFiles.compactMap(\.fileSize).reduce(0, +)
            self.predictedMergedSize = totalSize
            
            // 如果视频列表不为空，将第一项的文件名作为输出文件名
            if let firstVideo = self.videoFiles.first {
                self.outputFileName = firstVideo.name
            }
            
            // 合并后大小需在下一次合并成功后再更新
            self.mergedFileSize = nil
            
        } catch {
            print("读取文件夹内容出错：\(error)")
            self.videoFiles = []
            self.predictedMergedSize = nil
        }
    }
    
    /// 异步执行 yamdi 命令
    func startMerge() {
        // 检查目标输出文件是否已存在，防止覆盖
        if FileManager.default.fileExists(atPath: outputURL.path) {
            self.mergeStatus = .error
            notifyUser(title: "目标文件已存在", body: "输出文件名与目标文件夹中已有文件冲突，请更改输出文件名或输出文件夹。")
            return
        }
        
        guard !videoFiles.isEmpty else {
            self.mergeStatus = .error
            notifyUser(title: "合并出错", body: "没有可合并的视频文件")
            return
        }
        self.mergeStatus = .running
        
        let process = Process()
        // 使用 zsh -il -c 方式，确保加载 ~/.zshrc 和 ~/.zprofile
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-il", "-c", mergeCommand]
        
        process.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if p.terminationStatus == 0 {
                    self.mergeStatus = .success
                    self.notifyUser(title: "合并完成", body: "已成功合并视频到: \(self.outputURL.path)")
                    
                    // 获取合并后文件大小
                    let attributes = try? FileManager.default.attributesOfItem(atPath: self.outputURL.path)
                    if let size = attributes?[.size] as? Int {
                        self.mergedFileSize = size
                    }
                    
                    // 如果用户选择了“合并完成后删除源文件”，改为移动到统一的无用文件夹
                    if self.shouldDeleteSourceFiles {
                        // 确定目标文件夹路径，比如用户文档目录下的 "UselessVideos"
                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let trashFolderURL = documentsURL.appendingPathComponent(".UselessVideos")
                        
                        // 如果目标文件夹不存在，则创建
                        if !FileManager.default.fileExists(atPath: trashFolderURL.path) {
                            do {
                                try FileManager.default.createDirectory(at: trashFolderURL, withIntermediateDirectories: true, attributes: nil)
                            } catch {
                                print("创建无用文件夹出错：\(error)")
                            }
                        }
                        
                        // 移动每个源文件到目标文件夹
                        for file in self.videoFiles {
                            let originalURL = file.fileURL
                            // 构造目标文件路径
                            var destinationURL = trashFolderURL.appendingPathComponent(originalURL.lastPathComponent)
                            
                            // 如果目标文件已存在，则为避免冲突，在文件名后追加时间戳
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                let timestamp = Int(Date().timeIntervalSince1970)
                                let fileName = originalURL.deletingPathExtension().lastPathComponent
                                let fileExtension = originalURL.pathExtension
                                let newFileName = "\(fileName)_\(timestamp).\(fileExtension)"
                                destinationURL = trashFolderURL.appendingPathComponent(newFileName)
                            }
                            
                            do {
                                try FileManager.default.moveItem(at: originalURL, to: destinationURL)
                            } catch {
                                print("移动文件出错：\(error)")
                            }
                        }
                    }
                    
                    // 在 Finder 中选中输出文件
                    NSWorkspace.shared.activateFileViewerSelecting([self.outputURL])
                } else {
                    self.mergeStatus = .error
                    self.notifyUser(title: "合并出错", body: "请检查 yamdi 命令或文件路径是否正确")
                }
            }
        }
        
        do {
            try process.run()  // 异步启动
        } catch {
            // 如果命令无法执行，比如找不到 yamdi
            self.mergeStatus = .error
            notifyUser(title: "执行失败", body: "无法运行 yamdi，请检查环境变量或 yamdi 是否安装。")
        }
    }
    
    /// 发送本地通知（macOS 14+）
    private func notifyUser(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知发送失败: \(error)")
            }
        }
    }
    
    /// 用户在 UI 中勾选或取消勾选“合并后删除源文件”
    func toggleShouldDelete() {
        shouldDeleteSourceFiles.toggle()
        persistDeleteOption()
    }
}

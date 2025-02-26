//
//  VideoMergeModel.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//


import Foundation
import SwiftUI
import UserNotifications

// MARK: - 管理整体状态的数据模型
class VideoMergeModel: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let shouldDeleteKey = "ShouldDeleteSourceFiles"
    
    // 从 UserDefaults 加载“是否删除源文件”设置
    @Published var shouldDeleteSourceFiles: Bool
    
    // 存储合并后输出文件大小（字节），成功后更新
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
            return
        }
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            let flvFiles = fileURLs.filter { $0.pathExtension.lowercased() == "flv" }
            self.videoFiles = flvFiles.map { VideoFile(fileURL: $0) }
            // 初始按时间戳排序，用户可手动拖动调整
            self.videoFiles.sort { $0.timestamp < $1.timestamp }
            // 合并后大小需在下一次合并成功后再更新
            self.mergedFileSize = nil
        } catch {
            print("读取文件夹内容出错：\(error)")
            self.videoFiles = []
        }
    }
    
    /// 异步执行 yamdi 命令
    func startMerge() {
        guard !videoFiles.isEmpty else {
            self.mergeStatus = .error
            notifyUser(title: "合并出错", body: "没有可合并的视频文件")
            return
        }
        self.mergeStatus = .running
        
        let process = Process()
        // 使用 zsh -l -c 方式，加载用户环境
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
                    
                    // 如果用户选择了“合并完成后删除源文件”
                    if self.shouldDeleteSourceFiles {
                        for file in self.videoFiles {
                            do {
                                try FileManager.default.removeItem(at: file.fileURL)
                            } catch {
                                print("删除源文件出错：\(error)")
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
    
    // 在 UI 中勾选“合并后删除源文件”时调用
    func toggleShouldDelete() {
        shouldDeleteSourceFiles.toggle()
        persistDeleteOption()
    }
}

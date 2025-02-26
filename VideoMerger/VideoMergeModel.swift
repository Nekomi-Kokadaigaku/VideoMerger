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
            // 若发生修改，标记为用户已手动修改
            if oldValue != outputFilePath {
                isOutputPathUserModified = true
            }
        }
    }
    
    @Published var videoFiles: [VideoFile] = []
    
    // 用于表示合并过程状态（小圆点颜色、通知等）
    @Published var mergeStatus: MergeStatus = .idle
    
    /// 计算属性：生成 yamdi 合并命令
    var mergeCommand: String {
        // 根据当前顺序生成 -i 参数
        let inputs = videoFiles.map { "-i \"\($0.fileURL.path)\"" }
                               .joined(separator: " ")
        
        // 如果用户未指定输出路径，则默认使用当前目录
        guard let outputFolder = outputFilePath else {
            return "yamdi \(inputs) -o \"./\(outputFileName)\""
        }
        let output = outputFolder.appendingPathComponent(outputFileName).path
        return "yamdi \(inputs) -o \"\(output)\""
    }
    
    /// 计算属性：获取最终输出文件的 URL（便于在 Finder 中选中）
    var outputURL: URL {
        guard let folder = outputFilePath else {
            // 若未指定则返回当前目录下的 outputFileName
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
            // 初始按时间戳排序，用户也可手动拖动调整
            self.videoFiles.sort { $0.timestamp < $1.timestamp }
        } catch {
            print("读取文件夹内容出错：\(error)")
            self.videoFiles = []
        }
    }
    
    /// 异步执行 yamdi 命令，更新状态并在完成时通知
    func startMerge() {
        // 若没有可合并的视频文件，直接报错
        guard !videoFiles.isEmpty else {
            self.mergeStatus = .error
            notifyUser(title: "合并出错", body: "没有可合并的视频文件")
            return
        }
        
        // 状态置为运行中
        self.mergeStatus = .running
        
        // 在 zsh 环境下执行命令，确保加载用户环境变量（-l 为登录 shell）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", mergeCommand]
        
        // 监听进程结束
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let status = process.terminationStatus
                if status == 0 {
                    // 合并成功
                    self.mergeStatus = .success
                    self.notifyUser(title: "合并完成", body: "已成功合并视频到: \(self.outputURL.path)")
                    // 在 Finder 中选中输出文件
                    NSWorkspace.shared.activateFileViewerSelecting([self.outputURL])
                } else {
                    // 合并失败
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
        
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知发送失败: \(error)")
            }
        }
    }
}

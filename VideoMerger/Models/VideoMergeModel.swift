//
//  VideoMergeModel.swift
//  VideoMerger
//

import Foundation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers


/// 管理整体状态的数据模型
class VideoMergeModel: ObservableObject {
    /// 合并进程
    private var mergeProcess: Process?
    /// 用户默认设置
    private let userDefaults = UserDefaults.standard
    /// 是否删除源文件
    private let shouldDeleteKey = "shouldDeleteSourceFiles"
    /// 预测合并后文件大小
    @Published var predictedMergedSize: Int? = nil
    /// 是否删除源文件
    @Published var shouldDeleteSourceFiles: Bool
    /// 合并后文件大小
    @Published var mergedFileSize: Int? = nil
    /// 文件夹路径
    @Published var folderURL: URL? {
        didSet {
            loadVideoFiles()
            if !isOutputPathUserModified {
                outputFilePath = folderURL
            }
        }
    }
    /// 输出文件名
    @Published var outputFileName: String = "output.flv"
    /// 是否修改输出路径
    private var isOutputPathUserModified = false
    /// 输出路径
    @Published var outputFilePath: URL? {
        didSet {
            if oldValue != outputFilePath {
                isOutputPathUserModified = true
            }
        }
    }
    /// 视频文件列表
    @Published var videoFiles: [VideoFile] = []
    /// 合并状态
    @Published var mergeStatus: MergeStatus = .idle

    init() {
        self.shouldDeleteSourceFiles = userDefaults.bool(forKey: shouldDeleteKey)
    }

    /// 持久化删除选项
    private func persistDeleteOption() {
        userDefaults.set(shouldDeleteSourceFiles, forKey: shouldDeleteKey)
    }

    /// 合并命令
    var mergeCommand: String {
        let inputs = videoFiles.map { "-i \"\($0.fileURL.path)\"" }.joined(separator: " ")
        guard let outputFolder = outputFilePath else {
            return "yamdi \(inputs) -o \"./\(outputFileName)\""
        }
        let output = outputFolder.appendingPathComponent(outputFileName).path
        return "yamdi \(inputs) -o \"\(output)\""
    }

    /// 输出路径
    var outputURL: URL {
        guard let folder = outputFilePath else {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(outputFileName)
        }
        return folder.appendingPathComponent(outputFileName)
    }

    /// 扫描文件夹内的 .flv 文件并加载列表
    func loadVideoFiles() {
        guard let folder = folderURL else {
            videoFiles = []
            predictedMergedSize = nil
            return
        }
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            let flvFiles = fileURLs.filter { $0.pathExtension.lowercased() == "flv" }
            videoFiles = flvFiles.map { VideoFile(fileURL: $0) }
            videoFiles.sort { $0.timestamp < $1.timestamp }
            predictedMergedSize = videoFiles.compactMap(\.fileSize).reduce(0, +)
            if let firstVideo = videoFiles.first {
                outputFileName = firstVideo.name
            }
            mergedFileSize = nil
        } catch {
            print("读取文件夹内容出错：\(error)")
            videoFiles = []
            predictedMergedSize = nil
        }
    }

    /// 异步执行 yamdi 命令
    func startMerge() {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            mergeStatus = .error
            notifyUser(title: "目标文件已存在", body: "输出文件名与目标文件夹中已有文件冲突，请更改输出文件名或输出文件夹。")
            return
        }

        guard !videoFiles.isEmpty else {
            mergeStatus = .error
            notifyUser(title: "合并出错", body: "没有可合并的视频文件")
            return
        }
        mergeStatus = .running
        let process = Process()
        mergeProcess = process
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-il", "-c", mergeCommand]

        process.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.mergeProcess = nil
                if p.terminationStatus == 0 {
                    self.mergeStatus = .success
                    self.notifyUser(title: "合并完成", body: "已成功合并视频到: \(self.outputURL.path)")
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: self.outputURL.path),
                       let size = attributes[.size] as? Int {
                        self.mergedFileSize = size
                    }
                    if self.shouldDeleteSourceFiles {
                        self.moveSourceFilesToTrash()
                    }
                    NSWorkspace.shared.activateFileViewerSelecting([self.outputURL])
                } else {
                    if self.mergeStatus == .running {
                        self.mergeStatus = .idle
                        self.notifyUser(title: "合并取消", body: "合并操作已被取消")
                    } else {
                        self.mergeStatus = .error
                        self.notifyUser(title: "合并出错", body: "请检查 yamdi 命令或文件路径是否正确")
                    }
                }
            }
        }

        do {
            try process.run()
        } catch {
            mergeStatus = .error
            notifyUser(title: "执行失败", body: "无法运行 yamdi，请检查环境变量或 yamdi 是否安装。")
        }
    }

    /// 取消合并操作
    func cancelMerge() {
        if let process = mergeProcess {
            process.terminate()
            mergeProcess = nil
            mergeStatus = .idle
            notifyUser(title: "合并取消", body: "用户取消了合并操作")
        }
    }

    /// 发送本地通知
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

    /// 移动源文件到垃圾桶
    private func moveSourceFilesToTrash() {
        let defaults = UserDefaults.standard
        let trashPath = defaults.string(forKey: "trashFolderPath") ?? ""
        let trashFolderURL: URL
        if !trashPath.isEmpty {
            trashFolderURL = URL(fileURLWithPath: trashPath)
        } else {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            trashFolderURL = documentsURL.appendingPathComponent(".UselessVideos")
        }
        if !FileManager.default.fileExists(atPath: trashFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: trashFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("创建垃圾桶文件夹出错：\(error)")
            }
        }
        for file in videoFiles {
            let originalURL = file.fileURL
            var destinationURL = trashFolderURL.appendingPathComponent(originalURL.lastPathComponent)
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

    /// 用户切换“合并后删除源文件”
    func toggleShouldDelete() {
        shouldDeleteSourceFiles.toggle()
        persistDeleteOption()
    }

    /// 处理拖放文件，返回是否处理成功
    func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    if let error = error {
                        print("加载拖放文件出错: \(error)")
                        return
                    }
                    if let url = item as? URL {
                        self.processDroppedFile(url: url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        self.processDroppedFile(url: url)
                    }
                }
                found = true
            }
        }
        return found
    }

    /// 处理拖放文件
    private func processDroppedFile(url: URL) {
        guard url.pathExtension.lowercased() == "flv" else { return }
        DispatchQueue.main.async {
            if !self.videoFiles.contains(where: { $0.fileURL == url }) {
                let newVideo = VideoFile(fileURL: url)
                self.videoFiles.append(newVideo)
                self.predictedMergedSize = self.videoFiles.compactMap(\.fileSize).reduce(0, +)
            }
        }
    }
}

//
//  VideoMergeModel.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//


import Foundation
import SwiftUI

// MARK: - 管理整体状态的数据模型

class VideoMergeModel: ObservableObject {
    @Published var folderURL: URL? {
        didSet {
            loadVideoFiles()
            // 当用户选择新文件夹后，如果用户尚未手动修改过输出路径，则将输出路径设为同一文件夹
            // 如果你希望始终同步，则可直接取消条件判断，改为：outputFilePath = folderURL
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
    
    /// 根据当前视频文件列表和输出文件信息生成合并命令字符串
    var mergeCommand: String {
        // 这里的顺序以用户在列表中拖动的顺序为准
        let inputs = videoFiles.map { "-i \"\($0.fileURL.path)\"" }
                               .joined(separator: " ")
        // 如果用户未指定输出路径，则默认使用当前目录
        guard let outputFolder = outputFilePath else {
            return "yamdi \(inputs) -o \"./\(outputFileName)\""
        }
        let output = outputFolder.appendingPathComponent(outputFileName).path
        return "yamdi \(inputs) -o \"\(output)\""
    }
    
    /// 读取指定文件夹内所有的 .flv 文件，并按文件名中的时间戳排序（初始排序）
    func loadVideoFiles() {
        guard let folder = folderURL else {
            videoFiles = []
            return
        }
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            let flvFiles = fileURLs.filter { $0.pathExtension.lowercased() == "flv" }
            self.videoFiles = flvFiles.map { VideoFile(fileURL: $0) }
            // 初始按时间戳排序，之后用户可自行拖动调整顺序
            self.videoFiles.sort { $0.timestamp < $1.timestamp }
        } catch {
            print("读取文件夹内容出错：\(error)")
            self.videoFiles = []
        }
    }
}


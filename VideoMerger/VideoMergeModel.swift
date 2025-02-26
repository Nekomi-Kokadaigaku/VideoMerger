//
//  VideoMergeModel.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//


import Foundation
import SwiftUI

/// 管理整体状态的数据模型
class VideoMergeModel: ObservableObject {
    @Published var folderURL: URL? {
        didSet {
            // 当文件夹改变时加载文件，同时更新输出文件路径（如果还未手动设置）
            loadVideoFiles()
            if outputFilePath == nil {
                outputFilePath = folderURL
            }
        }
    }
    @Published var outputFileName: String = "output.flv"
    @Published var outputFilePath: URL?
    @Published var videoFiles: [VideoFile] = []
    
    /// 根据当前视频文件列表和输出文件信息生成合并命令字符串
    var mergeCommand: String {
        // 这里的排序顺序以用户调整为准
        let inputs = videoFiles.map { "-i \"\($0.fileURL.path)\"" }
                                 .joined(separator: " ")
        let output: String
        if let outputFolder = outputFilePath {
            output = outputFolder.appendingPathComponent(outputFileName).path
        } else {
            output = "./\(outputFileName)"
        }
        return "yamdi \(inputs) -o \"\(output)\""
    }
    
    /// 读取指定文件夹内所有的 .flv 文件，并按文件名中的时间戳排序（初始排序）
    func loadVideoFiles() {
        guard let folder = folderURL else { return }
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


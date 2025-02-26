//
//  VideoFile.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//


import Foundation

/// 表示单个视频文件的信息
struct VideoFile: Identifiable {
    let id = UUID()             // 用于唯一标识，便于列表排序和拖动
    let name: String            // 文件名，如 "20230101-123456.flv"
    let fileURL: URL            // 文件的完整路径
    let timestamp: Date         // 从文件名中提取的时间戳，用于初始排序

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.name = fileURL.lastPathComponent
        // 尝试从文件名中提取时间戳，格式：YYYYMMDD-HHMMSS
        if let date = VideoFile.extractTimestamp(from: fileURL.lastPathComponent) {
            self.timestamp = date
        } else {
            self.timestamp = Date.distantPast
        }
    }
    
    /// 使用正则表达式解析文件名中的时间戳
    static func extractTimestamp(from fileName: String) -> Date? {
        let pattern = "(\\d{8}-\\d{6})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: fileName.utf16.count)
        if let match = regex.firstMatch(in: fileName, options: [], range: range),
           let swiftRange = Range(match.range(at: 1), in: fileName) {
            let timestampString = String(fileName[swiftRange])
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            return formatter.date(from: timestampString)
        }
        return nil
    }
}

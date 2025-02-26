//
//  VideoFile.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//


import Foundation

// MARK: - 单个视频文件的数据结构
struct VideoFile: Identifiable {
    let id = UUID()             // 用于唯一标识，便于列表排序和拖动
    let name: String            // 文件名，如 "20230101-123456.flv"
    let fileURL: URL            // 文件的完整路径
    let timestamp: Date         // 从文件名中解析的时间戳
    let fileSize: Int?          // 文件大小（字节）
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.name = fileURL.lastPathComponent
        self.timestamp = VideoFile.extractTimestamp(from: fileURL.lastPathComponent) ?? Date.distantPast
        
        // 尝试获取文件大小（字节）
        if let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attr[.size] as? Int {
            self.fileSize = size
        } else {
            self.fileSize = nil
        }
    }
    
    // 将文件大小转换为易读格式
    var sizeString: String {
        if let size = fileSize {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(size))
        } else {
            return "未知"
        }
    }
    
    /// 尝试从文件名中解析出 "YYYYMMDD-HHMMSS" 的时间戳
    static func extractTimestamp(from fileName: String) -> Date? {
        let pattern = "(\\d{8}-\\d{6})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
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

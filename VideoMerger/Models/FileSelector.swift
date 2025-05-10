//
//  FileSelector.swift
//  VideoMerger
//

import AppKit
import UniformTypeIdentifiers


/// 通用的文件夹选择器，支持传入初始路径 key 和允许的类型
struct FileSelector {
    
    static func selectFolder(
        allowedContentTypes: [UTType]?,
        initialPathKey: String,
        completion: @escaping (URL) -> Void
    ) {
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = (allowedContentTypes != nil)
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if let lastPath = UserDefaults.standard.string(forKey: initialPathKey) {
            panel.directoryURL = URL(fileURLWithPath: lastPath)
        }

        if let types = allowedContentTypes, !types.isEmpty {
            panel.allowedContentTypes = types
        }

        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }
}

//
//  TrashManager.swift
//  VideoMerger
//

import Foundation


class TrashManager {

  static let shared = TrashManager()

  private init() {}

  /// 检查垃圾桶大小是否超过阈值，如果超过则清空
  func checkTrashFolderSizeAndClearIfNeeded() {
    let defaults = UserDefaults.standard

    guard let trashFolderPath = defaults.string(forKey: "trashFolderPath"),
      !trashFolderPath.isEmpty
    else {
      print("尚未设置垃圾桶路径，跳过清理")
      return
    }

    let thresholdGB = defaults.integer(forKey: "trashClearThresholdGB")
    guard thresholdGB > 0 else {
      print("尚未设置有效的垃圾桶清空阈值，跳过清理")
      return
    }

    let trashURL = URL(fileURLWithPath: trashFolderPath)

    // 计算文件夹大小（字节）
    let folderSize = calculateFolderSize(at: trashURL)

    // 将 GB 转换为字节
    let thresholdBytes = Int64(thresholdGB) * 1024 * 1024 * 1024

    if folderSize > thresholdBytes {
      clearTrashFolder(at: trashURL)
    }
  }

  /// 计算指定文件夹大小（仅计算当前目录下文件）
  private func calculateFolderSize(at folderURL: URL) -> Int64 {
    var totalSize: Int64 = 0
    do {
      let fileURLs = try FileManager.default.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles])
      for fileURL in fileURLs {
        if let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey])
          .fileSize
        {
          totalSize += Int64(fileSize)
        }
      }
    } catch {
      print("读取垃圾桶文件夹内容出错: \(error)")
    }
    return totalSize
  }

  /// 清空垃圾桶文件夹
  private func clearTrashFolder(at trashURL: URL) {
    do {
      let fileURLs = try FileManager.default.contentsOfDirectory(
        at: trashURL,
        includingPropertiesForKeys: nil,
        options: [])
      for fileURL in fileURLs {
        try FileManager.default.removeItem(at: fileURL)
      }
      print("垃圾桶已清空")
    } catch {
      print("清空垃圾桶时出错: \(error)")
    }
  }
}

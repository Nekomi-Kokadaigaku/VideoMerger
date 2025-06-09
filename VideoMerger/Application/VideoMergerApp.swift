//
//  VideoMergerApp.swift
//  VideoMerger
//

import SwiftUI
import UserNotifications


@main
struct VideoMergerApp: App {

  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

  init() {
    NotificationManager.shared.checkAndRequestPermission()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }

    Settings {
      SettingsView()
    }
  }
}


/// 自定义 AppDelegate，用于应用退出前清理垃圾桶
class AppDelegate: NSObject, NSApplicationDelegate {

  func applicationWillTerminate(_ notification: Notification) {
    // 在程序退出前检查垃圾桶文件夹大小，并根据阈值清空垃圾桶
    TrashManager.shared.checkTrashFolderSizeAndClearIfNeeded()
  }
}

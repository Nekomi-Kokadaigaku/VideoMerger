//
//  VideoMergerApp.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
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

/// 自定义 AppDelegate，用于捕捉应用退出事件
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // 在程序退出前检查垃圾桶文件夹大小，并根据阈值清空垃圾桶
        TrashManager.shared.checkTrashFolderSizeAndClearIfNeeded()
    }
}

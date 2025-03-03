//
//  NotificationManager.swift
//  VideoMerger
//
//  Created by Iris on 2025-03-04.
//


import SwiftUI
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private let notificationPromptCountKey = "NotificationPromptCount"
    
    private init() {}
    
    /// 检查通知权限并请求，如果权限为未决定则发起请求，如果为拒绝且提示次数未满3次，则展示提示
    func checkAndRequestPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // 尚未决定，直接请求权限
                    self.requestPermission()
                case .denied:
                    // 如果用户已经拒绝，则判断提示次数，最多提示3次
                    let count = UserDefaults.standard.integer(forKey: self.notificationPromptCountKey)
                    if count < 3 {
                        self.showAlertToOpenSettings()
                        UserDefaults.standard.set(count + 1, forKey: self.notificationPromptCountKey)
                    } else {
                        print("已提示用户3次，不再弹出提示")
                    }
                default:
                    break
                }
            }
        }
    }
    
    /// 请求通知权限
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("请求通知权限出错：\(error)")
            } else {
                print("通知权限请求结果：\(granted)")
            }
        }
    }
    
    /// 提示用户如何手动开启通知权限（macOS下无法直接打开设置）
    func showAlertToOpenSettings() {
        let alert = NSAlert()
        alert.messageText = "通知未开启"
        alert.informativeText = "请在系统偏好设置中为应用开启通知权限。\n（路径：系统偏好设置 -> 通知）"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    /// 发送通知，发送之前先检查授权状态
    func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("通知未授权，无法发送通知")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content,
                                                trigger: nil)
            center.add(request) { error in
                if let error = error {
                    print("发送通知失败：\(error)")
                }
            }
        }
    }
}

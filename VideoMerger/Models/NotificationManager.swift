//
//  NotificationManager.swift
//  VideoMerger
//

import SwiftUI
import UserNotifications


class NotificationManager {

  static let shared = NotificationManager()

  private let notificationPromptCountKey = "NotificationPromptCount"

  private init() {}

  /// 检查通知权限，并根据状态请求或提示
  func checkAndRequestPermission() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      DispatchQueue.main.async {
        switch settings.authorizationStatus {
        case .notDetermined:
          self.requestPermission()
        case .denied:
          let count = UserDefaults.standard.integer(
            forKey: self.notificationPromptCountKey)
          if count < 3 {
            self.showAlertToOpenSettings()
            UserDefaults.standard.set(
              count + 1, forKey: self.notificationPromptCountKey)
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
    center.requestAuthorization(options: [.alert, .sound, .badge]) {
      granted, error in
      if let error = error {
        print("请求通知权限出错：\(error)")
      } else {
        print("通知权限请求结果：\(granted)")
      }
    }
  }

  /// 提示用户如何手动开启通知权限
  func showAlertToOpenSettings() {
    let alert = NSAlert()
    alert.messageText = "通知未开启"
    alert.informativeText = "请在系统偏好设置中为应用开启通知权限。\n（路径：系统偏好设置 -> 通知）"
    alert.addButton(withTitle: "确定")
    alert.runModal()
  }

  /// 发送通知（在发送前检查授权）
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

      let request = UNNotificationRequest(
        identifier: UUID().uuidString,
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

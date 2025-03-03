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
    init() {
        NotificationManager.shared.checkAndRequestPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


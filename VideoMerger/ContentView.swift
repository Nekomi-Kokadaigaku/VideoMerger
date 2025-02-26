//
//  ContentView.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//

import SwiftUI
import UserNotifications

// MARK: - SwiftUI 主界面
struct ContentView: View {
    @ObservedObject var model = VideoMergeModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("VideoMerger")
                .font(.title)
                .padding(.bottom, 8)
            
            // ========== 文件夹选择 & 路径设置 ==========
            GroupBox(label: Text("视频文件夹选择")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("文件夹路径：")
                        TextField("请选择文件夹", text: Binding(
                            get: { model.folderURL?.path ?? "" },
                            set: { _ in }
                        ))
                        .disabled(true)
                        .frame(minWidth: 300)
                        
                        Button("选择文件夹") {
                            chooseFolder()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Text("输出设置")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("输出文件名：")
                        TextField("output.flv", text: $model.outputFileName)
                            .frame(minWidth: 200)
                    }
                    
                    HStack {
                        Text("输出文件路径：")
                        TextField("", text: Binding(
                            get: { model.outputFilePath?.path ?? "" },
                            set: { newValue in
                                model.outputFilePath = URL(fileURLWithPath: newValue)
                            }
                        ))
                        .frame(minWidth: 300)
                        
                        Button("选择输出文件夹") {
                            chooseOutputFolder()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // ========== 视频文件列表 ==========
            GroupBox(label: Text("合并视频文件列表（可拖动排序、删除） - \(model.videoFiles.count) 个文件")) {
                List {
                    ForEach(model.videoFiles) { video in
                        HStack {
                            Image(systemName: "line.horizontal.3")
                                .foregroundColor(.gray)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.name)
                                    .font(.headline)
                                Text("大小: \(video.sizeString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                // 显示时间戳（格式化后的日期）
                                if video.timestamp != Date.distantPast {
                                    Text("时间: \(formattedDate(video.timestamp))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                // 显示文件路径（可选，防止过长时截断）
                                Text("路径: \(video.fileURL.path)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            // 复制文件名按钮
                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(video.name, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .help("复制文件名")
                            // 删除按钮
                            Button {
                                if let index = model.videoFiles.firstIndex(where: { $0.id == video.id }) {
                                    model.videoFiles.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .help("删除该视频")
                        }
                        .contextMenu {
                            Button("删除") {
                                if let index = model.videoFiles.firstIndex(where: { $0.id == video.id }) {
                                    model.videoFiles.remove(at: index)
                                }
                            }
                        }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: deleteVideo)
                }
                .frame(minHeight: 150, maxHeight: 250)
            }
            
            // ========== 生成的合并指令 ==========
            GroupBox(label: Text("生成的合并指令")) {
                TextEditor(
                    text: Binding(
                        get: { model.mergeCommand },
                        set: { _ in }  // 伪只读，不修改
                    )
                )
                .frame(minHeight: 80, maxHeight: 120)
                .lineLimit(nil)
                // 保证可以滚动 & 复制
                .scrollContentBackground(.automatic)
                .padding(.vertical, 4)
            }
            
            // ========== 状态指示 & 开始合并 ==========
            HStack {
                AnimatedStatusCircle(status: model.mergeStatus)
                
                Text(statusText(for: model.mergeStatus))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("开始合并") {
                    model.startMerge()
                }
            }
            .padding(.top, 8)
            
        }
        // 让窗口有一个合适的默认尺寸
        .frame(minWidth: 600, minHeight: 500)
        .padding()
        .onAppear {
            // 请求通知权限
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("通知授权失败: \(error)")
                } else {
                    print("通知授权结果: \(granted)")
                }
            }
        }
    }
    
    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            model.outputFilePath = url
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 拖动排序处理
    func move(from source: IndexSet, to destination: Int) {
        model.videoFiles.move(fromOffsets: source, toOffset: destination)
    }
    
    // 删除视频项（列表左滑删除或右键删除）
    func deleteVideo(at offsets: IndexSet) {
        model.videoFiles.remove(atOffsets: offsets)
    }
    
    // 打开文件夹选择面板
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            model.folderURL = url
        }
    }
    
    // 根据 mergeStatus 返回不同的颜色
    func colorForStatus(_ status: MergeStatus) -> Color {
        switch status {
        case .idle:     return .gray
        case .running:  return .orange
        case .success:  return .green
        case .error:    return .red
        }
    }
    
    // 根据状态返回一个简短提示
    func statusText(for status: MergeStatus) -> String {
        switch status {
        case .idle:     return "就绪"
        case .running:  return "正在合并..."
        case .success:  return "合并完成"
        case .error:    return "合并出错"
        }
    }
}

#Preview {
    ContentView()
}

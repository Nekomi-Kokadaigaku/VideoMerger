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
        VStack(alignment: .leading, spacing: 10) {
            Text("VideoMerger").font(.title).padding(.bottom, 8)
            
            // 文件夹路径及选择按钮
            HStack {
                Text("文件夹路径：")
                TextField("请选择文件夹", text: Binding(
                    get: { model.folderURL?.path ?? "" },
                    set: { _ in } // 只读
                ))
                .disabled(true)
                .frame(minWidth: 300)
                
                Button("选择文件夹") {
                    chooseFolder()
                }
            }
            
            // 输出文件名
            HStack {
                Text("输出文件名：")
                TextField("output.flv", text: $model.outputFileName)
                    .frame(minWidth: 200)
            }
            
            // 输出文件路径
            HStack {
                Text("输出文件路径：")
                TextField("", text: Binding(
                    get: { model.outputFilePath?.path ?? "" },
                    set: { newValue in
                        model.outputFilePath = URL(fileURLWithPath: newValue)
                    }
                ))
                .frame(minWidth: 300)
            }
            
            // 视频文件列表（支持拖动排序）
            Text("合并视频文件列表（可拖动排序）：")
            List {
                ForEach(model.videoFiles) { video in
                    HStack {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(.gray)
                        Text(video.name)
                    }
                }
                .onMove(perform: move)
            }
            .frame(height: 150)
            
            // 生成的合并命令
            Text("生成的合并指令：")
            TextEditor(text: Binding(
                get: { model.mergeCommand },
                set: { _ in }  // 不允许用户修改，但可以复制
            ))
            .frame(height: 80)
            .border(Color.gray)
            .disabled(true)
            
            // 状态指示 + 开始合并按钮
            HStack {
                // 小圆点显示当前状态
                Circle()
                    .fill(colorForStatus(model.mergeStatus))
                    .frame(width: 14, height: 14)
                
                Spacer()
                
                Button("开始合并") {
                    model.startMerge()
                }
            }
            .padding(.top, 8)
        }
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
    
    // 拖动排序处理
    func move(from source: IndexSet, to destination: Int) {
        model.videoFiles.move(fromOffsets: source, toOffset: destination)
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
}

#Preview {
    ContentView()
}

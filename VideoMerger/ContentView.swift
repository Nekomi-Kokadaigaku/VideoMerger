//
//  ContentView.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model = VideoMergeModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("视频拼接工具")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            // 文件夹路径及选择按钮
            HStack {
                Text("文件夹路径：")
                TextField("请选择文件夹", text: Binding(
                    get: { model.folderURL?.path ?? "" },
                    set: { _ in }
                ))
                .disabled(true)
                Button("选择文件夹") {
                    chooseFolder()
                }
            }
            
            // 输出文件名称输入框
            HStack {
                Text("输出文件名称：")
                TextField("输出文件名称", text: $model.outputFileName)
                    .frame(width: 200)
            }
            
            // 输出文件路径输入框
            HStack {
                Text("输出文件路径：")
                TextField("输出文件路径", text: Binding(
                    get: { model.outputFilePath?.path ?? "" },
                    set: { newValue in
                        model.outputFilePath = URL(fileURLWithPath: newValue)
                    }
                ))
                .frame(width: 300)
            }
            
            // 支持拖动排序的视频文件列表
            Text("合并视频文件列表 (可拖动排序)：")
            List {
                ForEach(model.videoFiles) { video in
                    HStack {
                        Image(systemName: "line.horizontal.3")
                        Text(video.name)
                    }
                }
                .onMove(perform: move)
            }
            .frame(height: 200)
            
            // 实时展示生成的合并指令
            Text("生成的合并指令：")
            TextEditor(text: .constant(model.mergeCommand))
                .frame(height: 100)
                .disabled(true)
                .border(Color.gray)
            
            Spacer()
        }
        .padding()
    }
    
    /// 拖动排序处理方法
    func move(from source: IndexSet, to destination: Int) {
        model.videoFiles.move(fromOffsets: source, toOffset: destination)
    }
    
    /// 调用 NSOpenPanel 选择文件夹
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                model.folderURL = url
            }
        }
    }
}

#Preview {
    ContentView()
}

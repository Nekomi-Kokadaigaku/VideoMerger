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
        VStack(alignment: .leading, spacing: 12) {
            Text("VideoMerger")
                .font(.title)
                .padding(.bottom, 8)
            
            // 文件夹路径及选择按钮
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
            
            // 输出文件名称输入框
            HStack {
                Text("输出文件名：")
                TextField("output.flv", text: $model.outputFileName)
                    .frame(minWidth: 200)
            }
            
            // 输出文件路径输入框
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
            
            // 列表（支持拖动排序）
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
                set: { _ in }  // 不允许用户直接修改，但可以复制
            ))
            .frame(height: 80)
            .border(Color.gray)
            .disabled(true)
            
            Spacer()
        }
        .padding()
    }
    
    // 拖动排序处理方法
    func move(from source: IndexSet, to destination: Int) {
        model.videoFiles.move(fromOffsets: source, toOffset: destination)
    }
    
    // 使用 NSOpenPanel 选择文件夹
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

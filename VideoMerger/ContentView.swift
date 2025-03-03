//
//  ContentView.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//

import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

/// 主界面
struct ContentView: View {
    @ObservedObject var model = VideoMergeModel()
    @State private var alertMessage: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ========== 文件夹选择 & 路径设置 ==========
            GroupBox(label: Text("视频文件夹选择").font(.headline)) {
                HStack {
                    Text("文件夹路径：")
                        .font(.system(size: 14))
                    TextField("请选择文件夹", text: Binding(
                        get: { model.folderURL?.path ?? "" },
                        set: { _ in }
                    ))
                    .disabled(true)
                    .font(.system(size: 14))
                    .frame(minWidth: 300)

                    Button("选择文件夹") {
                        chooseFolder()
                    }
                    .font(.system(size: 14))
                }
                .padding(.vertical, 6)
            }

            GroupBox(label: Text("输出设置").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("输出文件名：")
                            .font(.system(size: 14))
                        TextField("output.flv", text: $model.outputFileName)
                            .font(.system(size: 14))
                            .frame(minWidth: 200)
                    }

                    HStack {
                        Text("输出文件路径：")
                            .font(.system(size: 14))
                        TextField("", text: Binding(
                            get: { model.outputFilePath?.path ?? "" },
                            set: { newValue in
                                model.outputFilePath = URL(fileURLWithPath: newValue)
                            }
                        ))
                        .font(.system(size: 14))
                        .frame(minWidth: 300)

                        Button("选择输出文件夹") {
                            chooseOutputFolder()
                        }
                        .font(.system(size: 14))
                    }

                    // 是否删除源文件的选择框
                    Toggle("合并完成后删除源文件", isOn: Binding(
                        get: { model.shouldDeleteSourceFiles },
                        set: { _ in
                            model.toggleShouldDelete()
                        }
                    ))
                    .font(.system(size: 14))
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
            }

            // ========== 视频文件列表 & 标题显示文件数、预计/实际大小 ==========
            GroupBox(label: groupBoxLabel()) {
                List {
                    ForEach(model.videoFiles) { video in
                        videoItemView(video)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: deleteVideo)
                }
                .frame(minHeight: 150, maxHeight: 250)
                // 添加 onDrop 修饰符，允许拖入文件
                .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleFileDrop)
            }

            // ========== 生成的合并指令 ==========
            GroupBox(label: Text("生成的合并指令").font(.headline)) {
                TextEditor(
                    text: Binding(
                        get: { model.mergeCommand },
                        set: { _ in }  // 伪只读，不修改
                    )
                )
                .frame(minHeight: 80, maxHeight: 120)
                .lineLimit(nil)
                .scrollContentBackground(.automatic)
                .padding(.vertical, 4)
                .font(.system(size: 12))
            }

            // ========== 状态指示 & 开始合并 ==========
            HStack {
                AnimatedStatusCircle(status: model.mergeStatus)

                Text(statusText(for: model.mergeStatus))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()
                
                if model.mergeStatus == .running {
                    Button("取消合并") {
                        model.cancelMerge()
                    }
                    .font(.system(size: 14))
                    .padding(.trailing, 10)
                }
                
                Button("开始合并") {
                    model.startMerge()
                }
                .font(.system(size: 14))
            }
            .padding(.top, 6)

        }
        .padding(12)
        .frame(minWidth: 620, minHeight: 550)
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

    // MARK: - 子视图 & 帮助函数

    /// GroupBox 标题：显示“合并视频文件列表 - N 个文件”，并在后面显示“预计合并后大小”和“实际合并后大小”
    @ViewBuilder
    private func groupBoxLabel() -> some View {
        HStack {
            Text("合并视频文件列表（可拖动排序、删除） - \(model.videoFiles.count) 个文件")
                .font(.headline)

            // 若已经加载到文件，则显示“预计合并后大小”
            if let predictedSize = model.predictedMergedSize, predictedSize > 0 {
                let sizeString = ByteCountFormatter().string(fromByteCount: Int64(predictedSize))
                Text("（预计合并后大小：\(sizeString)）")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // 若合并成功，显示“实际合并后大小”
            if let mergedSize = model.mergedFileSize, model.mergeStatus == .success {
                let sizeString = ByteCountFormatter().string(fromByteCount: Int64(mergedSize))
                Text("（实际：\(sizeString)）")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }

    /// 构建列表中的单个视频项视图
    private func videoItemView(_ video: VideoFile) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "line.horizontal.3")
                .foregroundColor(.gray)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(video.name)
                    .font(.system(size: 13, weight: .semibold))
                Text("大小: \(video.sizeString)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if video.timestamp != Date.distantPast {
                    Text("时间: \(formatDate(video.timestamp))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text("路径: \(video.fileURL.path)")
                    .font(.system(size: 11))
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
            .contextMenu {
                Button("删除") {
                    if let index = model.videoFiles.firstIndex(where: { $0.id == video.id }) {
                        model.videoFiles.remove(at: index)
                    }
                }
            }
        }
    }

    /// 拖动排序处理
    private func move(from source: IndexSet, to destination: Int) {
        model.videoFiles.move(fromOffsets: source, toOffset: destination)
    }

    /// 删除视频项
    private func deleteVideo(at offsets: IndexSet) {
        model.videoFiles.remove(atOffsets: offsets)
    }

    /// 打开文件夹选择面板
    private func chooseFolder() {
        let panel = NSOpenPanel()
        // 同时允许选择文件和目录
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // 如果选择文件，则只允许 flv 文件
//        panel.allowedFileTypes = ["flv"]
        panel.allowedContentTypes = [UTType(filenameExtension: "flv")!]

        // 尝试加载上次选择的文件夹路径
        if let lastFolderPath = UserDefaults.standard.string(forKey: "LastSelectedFolderPath") {
            panel.directoryURL = URL(fileURLWithPath: lastFolderPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            if url.hasDirectoryPath {
                // 如果用户选择的是文件夹，保存路径并将该文件夹作为视频文件所在目录
                UserDefaults.standard.set(url.path, forKey: "LastSelectedFolderPath")
                model.folderURL = url
            } else if url.pathExtension.lowercased() == "flv" {
                // 如果用户选择的是 flv 文件，则直接添加该文件到列表中
                if !model.videoFiles.contains(where: { $0.fileURL == url }) {
                    let newVideo = VideoFile(fileURL: url)
                    model.videoFiles.append(newVideo)
                    // 更新预计合并后的大小
                    let totalSize = model.videoFiles.compactMap(\.fileSize).reduce(0, +)
                    model.predictedMergedSize = totalSize
                }
            }
        }
    }

    /// 打开输出文件夹选择面板
    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        // 尝试加载上次的输出文件夹路径
        if let lastOutputPath = UserDefaults.standard.string(forKey: "LastOutputFolderPath") {
            panel.directoryURL = URL(fileURLWithPath: lastOutputPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            // 保存当前选择的输出文件夹路径
            UserDefaults.standard.set(url.path, forKey: "LastOutputFolderPath")
            model.outputFilePath = url
        }
    }

    /// 状态对应的提示文字
    private func statusText(for status: MergeStatus) -> String {
        switch status {
        case .idle:     return "就绪"
        case .running:  return "正在合并..."
        case .success:  return "合并完成"
        case .error:    return "合并出错"
        }
    }

    /// 状态对应的圆点颜色
    private func colorForStatus(_ status: MergeStatus) -> Color {
        switch status {
        case .idle:     return .gray
        case .running:  return .orange
        case .success:  return .green
        case .error:    return .red
        }
    }

    /// 格式化时间戳
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 处理拖放文件，添加到视频文件列表中
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                    if let error = error {
                        print("加载拖放文件出错: \(error)")
                        return
                    }

                    // 对 macOS，有时 item 会直接是 URL 类型
                    if let url = item as? URL {
                        processDroppedFile(url: url)
                    }
                    // 或者转换 Data 到 URL（备用方案）
                    else if let data = item as? Data,
                            let url = URL(dataRepresentation: data, relativeTo: nil) {
                        processDroppedFile(url: url)
                    }
                }
                found = true
            }
        }
        return found
    }

    /// 处理单个拖放进来的文件 URL
    private func processDroppedFile(url: URL) {
        // 只处理 flv 文件
        guard url.pathExtension.lowercased() == "flv" else { return }

        DispatchQueue.main.async {
            // 检查是否已存在同一文件
            if !model.videoFiles.contains(where: { $0.fileURL == url }) {
                let newVideo = VideoFile(fileURL: url)
                model.videoFiles.append(newVideo)

                // 更新预计合并后的大小
                let totalSize = model.videoFiles.compactMap(\.fileSize).reduce(0, +)
                model.predictedMergedSize = totalSize
            }
        }
    }

}

#Preview {
    ContentView()
}

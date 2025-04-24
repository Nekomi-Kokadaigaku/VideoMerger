//
//  ContentView.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-26.
//

import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model = VideoMergeModel()
    @State private var alertMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceFolderGroup
            outputSettingsGroup
            videoFilesGroup
            mergeCommandGroup
            statusAndMergeButtons
        }
        .padding(12)
        .frame(minWidth: 620, minHeight: 550)
        .onAppear(perform: requestNotificationPermission)
    }
}

// MARK: - UI 组件拆分
extension ContentView {
    private var sourceFolderGroup: some View {
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
                    selectSourceFolder()
                }
                .font(.system(size: 14))
            }
            .padding(.vertical, 6)
        }
    }

    private var outputSettingsGroup: some View {
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
                        selectOutputFolder()
                    }
                    .font(.system(size: 14))
                }

                Toggle("合并完成后删除源文件", isOn: Binding(
                    get: { model.shouldDeleteSourceFiles },
                    set: { _ in model.toggleShouldDelete() }
                ))
                .font(.system(size: 14))
                .padding(.top, 4)
            }
            .padding(.vertical, 6)
        }
    }

    private var videoFilesGroup: some View {
        GroupBox(label: videoFilesGroupLabel()) {
            List {
                ForEach(model.videoFiles) { video in
                    videoItemView(video)
                }
                .onMove(perform: moveVideo)
                .onDelete(perform: deleteVideo)
            }
            .frame(minHeight: 150, maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil, perform: model.handleFileDrop)
        }
    }

    private var mergeCommandGroup: some View {
        GroupBox(label: Text("生成的合并指令").font(.headline)) {
            TextEditor(text: Binding(
                get: { model.mergeCommand },
                set: { _ in }
            ))
            .frame(minHeight: 80, maxHeight: 120)
            .padding(.vertical, 4)
            .font(.system(size: 12))
        }
    }

    private var statusAndMergeButtons: some View {
        HStack {
            AnimatedStatusCircle(status: model.mergeStatus)
            Text(model.mergeStatus.description)
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

    private func videoFilesGroupLabel() -> some View {
        HStack {
            Text("合并视频文件列表（可拖动排序、删除） - \(model.videoFiles.count) 个文件")
                .font(.headline)
            if let predictedSize = model.predictedMergedSize, predictedSize > 0 {
                let sizeString = ByteCountFormatter.string(fromByteCount: Int64(predictedSize), countStyle: .file)
                Text("（预计合并后大小：\(sizeString)）")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            if let mergedSize = model.mergedFileSize, model.mergeStatus == .success {
                let sizeString = ByteCountFormatter.string(fromByteCount: Int64(mergedSize), countStyle: .file)
                Text("（实际：\(sizeString)）")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - 交互逻辑
extension ContentView {
    /// 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知授权失败: \(error)")
            } else {
                print("通知授权结果: \(granted)")
            }
        }
    }

    /// 选择源文件夹
    private func selectSourceFolder() {
        FileSelector.selectFolder(allowedContentTypes: [UTType(filenameExtension: "flv")!], initialPathKey: "LastSelectedFolderPath") { url in
            if url.hasDirectoryPath {
                UserDefaults.standard.set(url.path, forKey: "LastSelectedFolderPath")
                model.folderURL = url
            } else if url.pathExtension.lowercased() == "flv" {
                if !model.videoFiles.contains(where: { $0.fileURL == url }) {
                    model.videoFiles.append(VideoFile(fileURL: url))
                    model.predictedMergedSize = model.videoFiles.compactMap(\.fileSize).reduce(0, +)
                }
            }
        }
    }

    /// 选择输出文件夹
    private func selectOutputFolder() {
        FileSelector.selectFolder(allowedContentTypes: nil, initialPathKey: "LastOutputFolderPath") { url in
            UserDefaults.standard.set(url.path, forKey: "LastOutputFolderPath")
            model.outputFilePath = url
        }
    }

    /// 拖动排序
    private func moveVideo(from source: IndexSet, to destination: Int) {
        model.videoFiles.move(fromOffsets: source, toOffset: destination)
    }

    /// 删除视频项
    private func deleteVideo(at offsets: IndexSet) {
        model.videoFiles.remove(atOffsets: offsets)
    }

    /// 构建列表中单个视频项视图
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
                    Text("时间: \(video.formattedTimestamp)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text("路径: \(video.fileURL.path)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(video.name, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("复制文件名")

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
}

#Preview {
    ContentView()
}

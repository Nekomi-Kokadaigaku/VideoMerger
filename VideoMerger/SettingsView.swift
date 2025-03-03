//
//  SettingsView.swift
//  VideoMerger
//
//  Created by Iris on 2025-03-04.
//


import SwiftUI

enum SettingsItem: String, CaseIterable, Identifiable {
    case trash = "垃圾桶设置"
    case fileProcessing = "文件处理设置"

    var id: String { rawValue }
}

struct SettingsView: View {
    @State private var selectedItem: SettingsItem? = .trash

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(SettingsItem.allCases) { item in
                    Text(item.rawValue)
                        .tag(item)
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 150)
        } detail: {
            switch selectedItem {
            case .trash:
                TrashSettingsView()
            case .fileProcessing:
                FileProcessingSettingsView()
            default:
                Text("请选择一个设置项")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct TrashSettingsView: View {
    // 垃圾桶路径，默认路径为空，后续由用户选择后存入 UserDefaults
    @AppStorage("trashFolderPath") var trashFolderPath: String = ""
    // 垃圾桶清空阈值（单位 GB），默认10GB
    @AppStorage("trashClearThresholdGB") var trashClearThresholdGB: Int = 10
    // 临时变量，用于 TextField 显示和编辑
    @State private var tempThreshold: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("垃圾桶设置")
                .font(.headline)
                .bold()

            // 垃圾桶位置选择区域
            HStack {
                Text("垃圾桶位置:")
                    .frame(width: 80, alignment: .leading)
                TextField("", text: Binding(
                    get: { trashFolderPath },
                    set: { _ in }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(true)
                .frame(maxWidth: .infinity)
                Button("选择") {
                    chooseTrashFolder()
                }
                .padding(.horizontal, 5)
            }

            // 清空阈值设置，使用文本框允许用户手动输入
            HStack {
                Text("清空阈值 (GB):")
                    .frame(width: 100, alignment: .leading)
                Stepper(value: $trashClearThresholdGB, in: 8...1000, step: 8, onEditingChanged: { _ in
                    tempThreshold = "\(trashClearThresholdGB)"
                }) {
                    HStack {
                        TextField("", text: $tempThreshold)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                            .onChange(of: tempThreshold) { _, newValue in
                                validateThresholdInput(newValue)
                                applyThreshold()
                            }
                        Text("GB")
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .onAppear {
            tempThreshold = "\(trashClearThresholdGB)"
        }
    }

    /// 使用 NSOpenPanel 选择垃圾桶文件夹，并在选定位置下新建 .trash 文件夹
    func chooseTrashFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            // 在用户选择的位置下新建 .trash 文件夹
            let trashURL = url.appendingPathComponent(".trash")
            do {
                try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true, attributes: nil)
                trashFolderPath = trashURL.path
            } catch {
                print("创建 .trash 文件夹失败: \(error)")
            }
        }
    }

    /// 过滤输入，只允许数字
    func validateThresholdInput(_ value: String) {
        let filtered = value.filter { "0123456789".contains($0) }
        tempThreshold = filtered
    }

    /// 将用户输入的数值应用到垃圾桶清空阈值，并限制范围在 8 ~ 1000 GB 之间
    func applyThreshold() {
        if let intValue = Int(tempThreshold) {
            let correctedValue = max(8, min(intValue, 1000))
            trashClearThresholdGB = correctedValue
            tempThreshold = "\(correctedValue)"
        } else {
            tempThreshold = "\(trashClearThresholdGB)"
        }
    }
}

struct FileProcessingSettingsView: View {
    // 示例：合并后是否移动源文件的设置
    @AppStorage("shouldDeleteSourceFiles") var shouldDeleteSourceFiles: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("文件处理设置")
                .font(.headline)
                .bold()

            Toggle("合并后移动源文件", isOn: $shouldDeleteSourceFiles)
                .help("如果启用，合并后源文件将会移动到统一的垃圾桶")

            Spacer()
        }
        .padding(20)
    }
}

#Preview {
    SettingsView()
}

//
//  AnimatedStatusCircle.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-27.
//

import SwiftUI

struct AnimatedStatusCircle: View {
    let status: MergeStatus

    // 控制圆点大小的局部状态
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(colorForStatus(status))
            .frame(width: 14, height: 14)
            .scaleEffect(scale)
            // 当状态发生变化时，根据是否是 .running 来决定动画
            .onChange(of: status) { _, newStatus in
                if newStatus == .running {
                    // 启动“呼吸灯”动画（来回缩放）
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        scale = 1.2
                    }
                } else {
                    // 非运行状态，重置为正常大小
                    scale = 1.0
                }
            }
            // 视图出现时，如果一开始就是 .running，就直接开启动画
            .onAppear {
                if status == .running {
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        scale = 1.2
                    }
                }
            }
    }

    // 你原先的颜色函数可以放在这里或直接引用外部的 colorForStatus()
    func colorForStatus(_ status: MergeStatus) -> Color {
        switch status {
        case .idle:     return .gray
        case .running:  return .orange
        case .success:  return .green
        case .error:    return .red
        }
    }
}

//
//  AnimatedStatusCircle.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-27.
//

import SwiftUI

struct AnimatedStatusCircle: View {
    let status: MergeStatus
    @State private var animationScale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(status.circleColor)
            .frame(width: 14, height: 14)
            .scaleEffect(animationScale)
            .onAppear { updateAnimation(for: status) }
            .onChange(of: status) { _, newStatus in
                updateAnimation(for: newStatus)
            }
    }
    
    /// 根据当前状态启动或取消“呼吸灯”动画
    private func updateAnimation(for newStatus: MergeStatus) {
        if newStatus == .running {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                animationScale = 1.2
            }
        } else {
            animationScale = 1.0
        }
    }
}

#Preview {
    Group {
        AnimatedStatusCircle(status: .error)
        AnimatedStatusCircle(status: .idle)
        AnimatedStatusCircle(status: .running)
        AnimatedStatusCircle(status: .success)
    }
    .frame(width: 60, height: 50)
}

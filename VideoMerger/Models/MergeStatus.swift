//
//  MergeStatus.swift
//  VideoMerger
//

import SwiftUI


/// 合并状态指示
enum MergeStatus {
    case idle       // 空闲状态
    case running    // 正在处理
    case success    // 处理成功
    case error      // 出错
}


extension MergeStatus {

    /// 返回状态对应的颜色
    var circleColor: Color {
        switch self {
        case .idle:     return .gray
        case .running:  return .orange
        case .success:  return .green
        case .error:    return .red
        }
    }
    
    /// 返回状态对应的提示文字
    var description: String {
        switch self {
        case .idle:     return "就绪"
        case .running:  return "正在合并..."
        case .success:  return "合并完成"
        case .error:    return "合并出错"
        }
    }
}

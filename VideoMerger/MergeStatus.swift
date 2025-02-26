//
//  MergeStatus.swift
//  VideoMerger
//
//  Created by Iris on 2025-02-27.
//


// MARK: - 合并状态指示
enum MergeStatus {
    case idle       // 空闲状态
    case running    // 正在处理
    case success    // 处理成功
    case error      // 出错
}
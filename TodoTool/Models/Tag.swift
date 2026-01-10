// ==================== 标签模型 ====================
// 用于任务分类的标签，支持自定义名称和颜色

import Foundation
import SwiftUI

/// 标签颜色枚举
enum TagColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray

    /// 转换为 SwiftUI Color
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .red: return "红色"
        case .orange: return "橙色"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .pink: return "粉色"
        case .gray: return "灰色"
        }
    }
}

/// 标签数据模型
struct Tag: Codable, Identifiable, Equatable, Hashable {
    /// 唯一标识符
    let id: UUID
    /// 标签名称
    var name: String
    /// 标签颜色
    var color: TagColor
    /// 创建时间
    let createdAt: Date

    /// 便捷初始化器
    init(
        id: UUID = UUID(),
        name: String,
        color: TagColor = .blue,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}

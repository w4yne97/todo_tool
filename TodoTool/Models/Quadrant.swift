// ==================== 四象限分类模型 ====================
// 艾森豪威尔矩阵（Eisenhower Matrix）四象限分类
// 按「重要性 × 紧急性」将任务分为四个象限

import Foundation
import SwiftUI

/// 四象限分类枚举
/// - Q1: 重要且紧急 → 立即执行
/// - Q2: 重要但不紧急 → 计划安排
/// - Q3: 不重要但紧急 → 考虑委托
/// - Q4: 不重要且不紧急 → 考虑删除
enum Quadrant: String, CaseIterable, Identifiable, Hashable {
    case urgentImportant        // Q1: 重要且紧急
    case notUrgentImportant     // Q2: 重要但不紧急
    case urgentNotImportant     // Q3: 不重要但紧急
    case notUrgentNotImportant  // Q4: 不重要且不紧急

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .urgentImportant: return "重要且紧急"
        case .notUrgentImportant: return "重要但不紧急"
        case .urgentNotImportant: return "不重要但紧急"
        case .notUrgentNotImportant: return "不重要且不紧急"
        }
    }

    /// 简短名称（用于紧凑布局）
    var shortName: String {
        switch self {
        case .urgentImportant: return "紧急重要"
        case .notUrgentImportant: return "重要"
        case .urgentNotImportant: return "紧急"
        case .notUrgentNotImportant: return "其他"
        }
    }

    /// 行动建议
    var actionHint: String {
        switch self {
        case .urgentImportant: return "立即执行"
        case .notUrgentImportant: return "计划安排"
        case .urgentNotImportant: return "考虑委托"
        case .notUrgentNotImportant: return "考虑删除"
        }
    }

    /// 象限颜色
    var color: Color {
        switch self {
        case .urgentImportant: return .red
        case .notUrgentImportant: return .orange
        case .urgentNotImportant: return .yellow
        case .notUrgentNotImportant: return .gray
        }
    }

    /// 象限图标
    var iconName: String {
        switch self {
        case .urgentImportant: return "exclamationmark.circle.fill"
        case .notUrgentImportant: return "calendar.circle.fill"
        case .urgentNotImportant: return "arrow.right.circle.fill"
        case .notUrgentNotImportant: return "minus.circle.fill"
        }
    }

    /// 网格布局顺序（左上 → 右上 → 左下 → 右下）
    /// Q1(紧急重要) | Q2(重要不紧急)
    /// Q3(紧急不重要) | Q4(不紧急不重要)
    static var gridOrder: [Quadrant] {
        [.urgentImportant, .notUrgentImportant,
         .urgentNotImportant, .notUrgentNotImportant]
    }

    /// 根据重要性和紧急性判断象限
    static func from(isImportant: Bool, isUrgent: Bool) -> Quadrant {
        switch (isImportant, isUrgent) {
        case (true, true): return .urgentImportant
        case (true, false): return .notUrgentImportant
        case (false, true): return .urgentNotImportant
        case (false, false): return .notUrgentNotImportant
        }
    }

    /// 该象限是否为重要象限
    var isImportant: Bool {
        self == .urgentImportant || self == .notUrgentImportant
    }

    /// 该象限是否为紧急象限
    var isUrgent: Bool {
        self == .urgentImportant || self == .urgentNotImportant
    }
}

import Foundation
import SwiftUI

enum PriorityFilter: String, CaseIterable, Identifiable {
    case all
    case high
    case medium
    case low
    case none

    var id: String { rawValue }

    static var allCases: [PriorityFilter] {
        [.all, .high, .medium, .low, .none]
    }

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        case .none: return "无"
        }
    }

    var priority: Priority? {
        switch self {
        case .all: return nil
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .none: return Priority.none
        }
    }
}

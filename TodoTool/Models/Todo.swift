import Foundation

/// 单个待办事项的数据模型
/// 遵循 Codable 支持 JSON 序列化，Identifiable 支持 SwiftUI 列表，Equatable 支持比较
struct Todo: Codable, Identifiable, Equatable {
    /// 唯一标识符
    let id: UUID
    /// 任务标题（非空，最大 200 字符）
    var title: String
    /// 完成状态
    var isCompleted: Bool
    /// 创建时间（UTC）
    let createdAt: Date
    /// 完成时间（UTC，未完成时为 nil）
    var completedAt: Date?
    /// 最近修改时间（UTC）
    var updatedAt: Date
    
    /// 便捷初始化器，自动设置时间戳
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

// MARK: - JSON 编解码配置

extension Todo {
    /// 自定义 ISO8601 日期格式化器，支持毫秒可选
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// 无毫秒的兼容格式化器（用于解码）
    static let iso8601FormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    /// 用于 JSON 编解码的自定义日期策略编码器
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = iso8601Formatter.string(from: date)
            try container.encode(dateString)
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    
    /// 用于 JSON 编解码的自定义日期策略解码器
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // 尝试带毫秒格式
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            // 尝试不带毫秒格式
            if let date = iso8601FormatterNoFractional.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期格式: \(dateString)"
            )
        }
        return decoder
    }()
}

import Foundation

/// JSON 存储容器，包含版本号、任务数组和标签数组
/// 用于持久化存储，支持未来版本迁移
struct TodoData: Codable {
    /// 数据版本号，用于未来迁移
    let version: Int
    /// 任务数组
    var todos: [Todo]
    /// 标签数组
    var tags: [Tag]

    /// 空数据的默认值
    static let empty = TodoData(version: 1, todos: [], tags: [])

    /// 便捷初始化器（向后兼容旧版本无 tags 字段）
    init(version: Int, todos: [Todo], tags: [Tag] = []) {
        self.version = version
        self.todos = todos
        self.tags = tags
    }

    /// 自定义解码以支持向后兼容（旧数据无 tags 字段）
    enum CodingKeys: String, CodingKey {
        case version, todos, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        todos = try container.decode([Todo].self, forKey: .todos)
        // 向后兼容：旧数据无 tags 字段时默认为空数组
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
    }

    /// 使用自定义编解码器编码为 JSON Data
    func encoded() throws -> Data {
        try Todo.encoder.encode(self)
    }

    /// 从 JSON Data 解码
    static func decoded(from data: Data) throws -> TodoData {
        try Todo.decoder.decode(TodoData.self, from: data)
    }
}

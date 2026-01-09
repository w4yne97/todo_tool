import Foundation

/// JSON 存储容器，包含版本号和任务数组
/// 用于持久化存储，支持未来版本迁移
struct TodoData: Codable {
    /// 数据版本号，用于未来迁移
    let version: Int
    /// 任务数组
    var todos: [Todo]
    
    /// 空数据的默认值
    static let empty = TodoData(version: 1, todos: [])
    
    /// 使用自定义编解码器编码为 JSON Data
    func encoded() throws -> Data {
        try Todo.encoder.encode(self)
    }
    
    /// 从 JSON Data 解码
    static func decoded(from data: Data) throws -> TodoData {
        try Todo.decoder.decode(TodoData.self, from: data)
    }
}

import Foundation

/// 状态管理器 + 持久化层
/// 负责管理待办事项的状态并将数据持久化到 JSON 文件
final class TodoStore: ObservableObject {
    /// 任务列表，UI 通过 @Published 自动刷新
    @Published private(set) var todos: [Todo] = []
    
    /// 数据文件 URL
    private let dataURL: URL
    /// 备份文件 URL
    private let backupURL: URL
    /// 临时文件 URL
    private let tempURL: URL
    
    /// 文件管理器
    private let fileManager = FileManager.default
    
    /// 初始化 TodoStore
    /// - Parameter dataDirectory: 可选的数据目录，默认为 Application Support/TodoTool
    init(dataDirectory: URL? = nil) {
        let directory: URL
        if let dataDirectory = dataDirectory {
            directory = dataDirectory
        } else {
            // 使用 Application Support 目录
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            directory = appSupport.appendingPathComponent("TodoTool", isDirectory: true)
        }
        
        // 确保目录存在
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        
        self.dataURL = directory.appendingPathComponent("data.json")
        self.backupURL = directory.appendingPathComponent("data.json.backup")
        self.tempURL = directory.appendingPathComponent("data.json.tmp")
        
        // 加载数据
        load()
    }
    
    // MARK: - 数据加载
    
    /// 从 JSON 文件加载数据
    /// 加载优先级：主文件 → 备份文件 → 空数据
    func load() {
        // 尝试读取主数据文件
        if let data = try? Data(contentsOf: dataURL),
           let todoData = try? TodoData.decoded(from: data) {
            self.todos = todoData.todos
            return
        }
        
        // 主文件不存在或损坏，尝试备份文件
        if let data = try? Data(contentsOf: backupURL),
           let todoData = try? TodoData.decoded(from: data) {
            self.todos = todoData.todos
            // 从备份恢复后，重新保存主文件
            try? save()
            return
        }
        
        // 无有效数据，使用空数据
        self.todos = []
    }
    
    // MARK: - 原子写入
    
    /// 将当前数据原子性写入文件
    /// 写入流程：数据 → tmp → backup → rename
    /// - Throws: 写入过程中的任何错误
    func save() throws {
        let todoData = TodoData(version: 1, todos: todos)
        let data = try todoData.encoded()
        
        // Step 1: 写入临时文件
        try data.write(to: tempURL, options: .atomic)
        
        // Step 2: 如果主文件存在，重命名为备份
        if fileManager.fileExists(atPath: dataURL.path) {
            // 删除旧备份
            try? fileManager.removeItem(at: backupURL)
            // 主文件 → 备份
            try fileManager.moveItem(at: dataURL, to: backupURL)
        }
        
        // Step 3: 临时文件 → 主文件
        try fileManager.moveItem(at: tempURL, to: dataURL)
    }
    
    // MARK: - CRUD 操作（Phase 3 实现）
    
    /// 添加新任务
    /// - Parameters:
    ///   - title: 任务标题
    ///   - priority: 任务优先级
    func add(title: String, priority: Priority = .none) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              title.count <= 200 else {
            return
        }
        
        let todo = Todo(title: title, priority: priority)
        todos.insert(todo, at: 0) // 最新的在最前
        try? save()
    }
    
    /// 切换任务完成状态
    /// - Parameter id: 任务 ID
    func toggle(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var todo = todos[index]
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? Date() : nil
        todo.updatedAt = Date()
        todos[index] = todo
        try? save()
    }
    
    /// 删除任务
    /// - Parameter id: 任务 ID
    func delete(id: UUID) {
        todos.removeAll { $0.id == id }
        try? save()
    }
    
    /// 更新任务标题
    /// - Parameters:
    ///   - id: 任务 ID
    ///   - title: 新标题
    func update(id: UUID, title: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              title.count <= 200 else {
            return
        }
        
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var todo = todos[index]
        todo.title = title
        todo.updatedAt = Date()
        todos[index] = todo
        try? save()
    }
    
    /// 设置任务优先级
    /// - Parameters:
    ///   - id: 任务 ID
    ///   - priority: 新优先级
    func setPriority(id: UUID, priority: Priority) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var todo = todos[index]
        todo.priority = priority
        todo.updatedAt = Date()
        todos[index] = todo
        try? save()
    }
    
    // MARK: - 导入功能

    /// 从 JSON 数据导入任务
    /// - Parameters:
    ///   - data: JSON 数据
    ///   - mode: 导入模式
    /// - Returns: 导入结果（新增数量，跳过数量）
    /// - Throws: 解码错误
    func importTodos(from data: Data, mode: ImportMode) throws -> (added: Int, skipped: Int) {
        let todoData = try TodoData.decoded(from: data)
        let newTodos = todoData.todos
        switch mode {
        case .replace:
            // 覆盖模式：直接替换所有数据
            todos = newTodos
            try? save()
            return (added: newTodos.count, skipped: 0)

        case .merge:
            // 合并模式：只添加不存在的任务
            let existingIds = Set(todos.map { $0.id })
            let newUniqueTodos = newTodos.filter { !existingIds.contains($0.id) }

            // 新任务插入到列表开头
            todos.insert(contentsOf: newUniqueTodos, at: 0)
            try? save()

            return (added: newUniqueTodos.count, skipped: newTodos.count - newUniqueTodos.count)
        }
    }

    // MARK: - 辅助查询

    /// 获取过滤并排序后的任务列表
    /// - Parameters:
    ///   - searchText: 搜索关键词
    ///   - priorityFilter: 优先级筛选（可选）
    /// - Returns: 处理后的任务列表
    func filteredAndSortedTodos(searchText: String = "", priorityFilter: Priority? = nil) -> [Todo] {
        var result = todos
        
        // 1. 过滤
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let priority = priorityFilter {
            result = result.filter { $0.priority == priority }
        }
        
        // 2. 排序
        // 优先级越高 (sortRank 小) 越靠前
        // 同优先级下，创建时间越晚越靠前 (最新在最前)
        result.sort {
            if $0.priority.sortRank != $1.priority.sortRank {
                return $0.priority.sortRank < $1.priority.sortRank
            }
            return $0.createdAt > $1.createdAt
        }
        
        return result
    }
}

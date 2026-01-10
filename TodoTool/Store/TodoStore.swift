import Foundation

// MARK: - Array 扩展

extension Array {
    /// 安全的下标访问，越界时返回 nil
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// 状态管理器 + 持久化层
/// 负责管理待办事项的状态并将数据持久化到 JSON 文件
final class TodoStore: ObservableObject {
    /// 任务列表，UI 通过 @Published 自动刷新
    @Published private(set) var todos: [Todo] = []
    /// 标签列表
    @Published private(set) var tags: [Tag] = []

    /// 数据文件 URL
    private let dataURL: URL
    /// 备份文件 URL
    private let backupURL: URL
    /// 临时文件 URL
    private let tempURL: URL

    /// 文件管理器
    private let fileManager = FileManager.default

    // MARK: - 撤销/重做（历史栈）

    /// 历史状态栈
    private var history: [[Todo]] = []
    /// 当前历史位置
    private var historyIndex: Int = -1
    /// 最大历史深度
    private let maxHistorySize = 50

    /// 是否可以撤销
    var canUndo: Bool {
        historyIndex > 0
    }

    /// 是否可以重做
    var canRedo: Bool {
        historyIndex < history.count - 1
    }
    
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

        // 初始化历史栈（将加载后的状态作为初始状态）
        initHistory()
    }

    // MARK: - 历史栈管理

    /// 初始化历史栈
    private func initHistory() {
        history = [todos]
        historyIndex = 0
    }

    /// 保存当前状态到历史栈
    private func saveState() {
        // 如果不在历史末尾，丢弃后续历史（新分支）
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }

        // 添加当前状态
        history.append(todos)
        historyIndex = history.count - 1

        // 超过最大深度时移除最旧的状态
        if history.count > maxHistorySize {
            history.removeFirst()
            historyIndex -= 1
        }
    }

    /// 撤销上一步操作
    func undo() {
        guard canUndo else { return }
        historyIndex -= 1
        todos = history[historyIndex]
        try? save()
    }

    /// 重做已撤销的操作
    func redo() {
        guard canRedo else { return }
        historyIndex += 1
        todos = history[historyIndex]
        try? save()
    }
    
    // MARK: - 数据加载

    /// 从 JSON 文件加载数据
    /// 加载优先级：主文件 → 备份文件 → 空数据
    func load() {
        // 尝试读取主数据文件
        if let data = try? Data(contentsOf: dataURL),
           let todoData = try? TodoData.decoded(from: data) {
            self.todos = todoData.todos
            self.tags = todoData.tags
            return
        }

        // 主文件不存在或损坏，尝试备份文件
        if let data = try? Data(contentsOf: backupURL),
           let todoData = try? TodoData.decoded(from: data) {
            self.todos = todoData.todos
            self.tags = todoData.tags
            // 从备份恢复后，重新保存主文件
            try? save()
            return
        }

        // 无有效数据，使用空数据
        self.todos = []
        self.tags = []
    }

    // MARK: - 原子写入

    /// 将当前数据原子性写入文件
    /// 写入流程：数据 → tmp → backup → rename
    /// - Throws: 写入过程中的任何错误
    func save() throws {
        let todoData = TodoData(version: 1, todos: todos, tags: tags)
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
        
        // 新任务的 sortOrder 设为最小值（比现有最小值还小）
        let minSortOrder = todos.map { $0.sortOrder }.min() ?? 0
        let todo = Todo(title: title, priority: priority, sortOrder: minSortOrder - 1)
        todos.insert(todo, at: 0) // 最新的在最前
        try? save()
        saveState()
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
        saveState()
    }

    /// 删除任务
    /// - Parameter id: 任务 ID
    func delete(id: UUID) {
        todos.removeAll { $0.id == id }
        try? save()
        saveState()
    }

    /// 批量删除任务
    /// - Parameter ids: 要删除的任务 ID 集合
    func deleteMultiple(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        todos.removeAll { ids.contains($0.id) }
        try? save()
        saveState()
    }

    /// 清除所有已完成的任务
    func clearCompleted() {
        let completedIds = Set(todos.filter { $0.isCompleted }.map { $0.id })
        guard !completedIds.isEmpty else { return }
        todos.removeAll { $0.isCompleted }
        try? save()
        saveState()
    }

    /// 批量切换完成状态
    /// - Parameters:
    ///   - ids: 要切换的任务 ID 集合
    ///   - completed: 目标完成状态
    func setCompleted(ids: Set<UUID>, completed: Bool) {
        guard !ids.isEmpty else { return }
        for index in todos.indices {
            if ids.contains(todos[index].id) {
                todos[index].isCompleted = completed
                todos[index].completedAt = completed ? Date() : nil
                todos[index].updatedAt = Date()
            }
        }
        try? save()
        saveState()
    }

    /// 批量设置优先级
    /// - Parameters:
    ///   - ids: 任务 ID 集合
    ///   - priority: 目标优先级
    func setPriorityMultiple(ids: Set<UUID>, priority: Priority) {
        guard !ids.isEmpty else { return }
        for index in todos.indices {
            if ids.contains(todos[index].id) {
                todos[index].priority = priority
                todos[index].updatedAt = Date()
            }
        }
        try? save()
        saveState()
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
        saveState()
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
        saveState()
    }

    /// 设置任务到期日期
    /// - Parameters:
    ///   - id: 任务 ID
    ///   - dueDate: 到期日期（nil 表示清除）
    func setDueDate(id: UUID, dueDate: Date?) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            return
        }

        var todo = todos[index]
        todo.dueDate = dueDate
        todo.updatedAt = Date()
        todos[index] = todo
        try? save()
        saveState()
    }

    /// 移动任务到新位置（拖拽排序）
    /// - Parameters:
    ///   - source: 源索引集
    ///   - destination: 目标索引
    ///   - inSection: 该分组的任务列表（待办或已完成）
    func move(from source: IndexSet, to destination: Int, inSection sectionTodos: [Todo]) {
        // 获取被移动的任务
        guard let sourceIndex = source.first,
              sourceIndex < sectionTodos.count else { return }

        let movedTodo = sectionTodos[sourceIndex]

        // 计算实际目标位置（考虑源元素移除后的偏移）
        let adjustedDest = destination > sourceIndex ? destination - 1 : destination

        // 确保目标位置有效
        guard adjustedDest >= 0 && adjustedDest < sectionTodos.count else { return }

        // 计算新的 sortOrder
        var newSortOrder: Int

        if adjustedDest == 0 {
            // 移动到最前面
            let firstTodo = sectionTodos.first { $0.id != movedTodo.id }
            let firstSortOrder = firstTodo?.sortOrder ?? 0
            newSortOrder = firstSortOrder - 10
        } else if adjustedDest >= sectionTodos.count - 1 {
            // 移动到最后面
            let lastTodo = sectionTodos.last { $0.id != movedTodo.id }
            let lastSortOrder = lastTodo?.sortOrder ?? 0
            newSortOrder = lastSortOrder + 10
        } else {
            // 移动到中间：计算相邻元素的 sortOrder 平均值
            // 找到目标位置前后的元素（排除被移动的元素）
            var neighbors: [Todo] = []
            for (index, todo) in sectionTodos.enumerated() {
                if todo.id != movedTodo.id {
                    neighbors.append(todo)
                }
            }

            // adjustedDest 是移除源元素后的目标位置
            let beforeIndex = adjustedDest - 1
            let afterIndex = adjustedDest

            let beforeOrder = neighbors[safe: beforeIndex]?.sortOrder ?? 0
            let afterOrder = neighbors[safe: afterIndex]?.sortOrder ?? beforeOrder + 20
            newSortOrder = (beforeOrder + afterOrder) / 2

            // 如果平均值相同（说明差值太小），重新编排所有 sortOrder
            if newSortOrder == beforeOrder || newSortOrder == afterOrder {
                renormalizeSortOrders()
                // 重新计算
                if let index = todos.firstIndex(where: { $0.id == movedTodo.id }) {
                    var todo = todos[index]
                    todo.sortOrder = adjustedDest * 10
                    todo.updatedAt = Date()
                    todos[index] = todo
                }
                try? save()
                saveState()
                return
            }
        }

        // 更新被移动任务的 sortOrder
        if let index = todos.firstIndex(where: { $0.id == movedTodo.id }) {
            var todo = todos[index]
            todo.sortOrder = newSortOrder
            todo.updatedAt = Date()
            todos[index] = todo
        }

        try? save()
        saveState()
    }

    /// 重新编排所有任务的 sortOrder（当差值太小时）
    private func renormalizeSortOrders() {
        for (index, var todo) in todos.enumerated() {
            todo.sortOrder = index * 10
            todos[index] = todo
        }
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
            saveState()
            return (added: newTodos.count, skipped: 0)

        case .merge:
            // 合并模式：只添加不存在的任务
            let existingIds = Set(todos.map { $0.id })
            let newUniqueTodos = newTodos.filter { !existingIds.contains($0.id) }

            // 新任务插入到列表开头
            todos.insert(contentsOf: newUniqueTodos, at: 0)
            try? save()
            saveState()

            return (added: newUniqueTodos.count, skipped: newTodos.count - newUniqueTodos.count)
        }
    }

    // MARK: - 辅助查询

    /// 获取过滤并排序后的任务列表
    /// - Parameters:
    ///   - searchText: 搜索关键词
    ///   - priorityFilter: 优先级筛选（可选）
    ///   - tagFilter: 标签筛选（可选）
    /// - Returns: 处理后的任务列表
    func filteredAndSortedTodos(searchText: String = "", priorityFilter: Priority? = nil, tagFilter: UUID? = nil) -> [Todo] {
        var result = todos

        // 1. 过滤
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        if let priority = priorityFilter {
            result = result.filter { $0.priority == priority }
        }

        if let tagId = tagFilter {
            result = result.filter { $0.tagIds.contains(tagId) }
        }

        // 2. 排序
        // 优先级越高 (sortRank 小) 越靠前
        // 同优先级下，按 sortOrder 排序（越小越靠前）
        // sortOrder 相同时，按创建时间排序（越晚越靠前）
        result.sort {
            if $0.priority.sortRank != $1.priority.sortRank {
                return $0.priority.sortRank < $1.priority.sortRank
            }
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.createdAt > $1.createdAt
        }

        return result
    }

    // MARK: - 标签管理

    /// 添加新标签
    /// - Parameters:
    ///   - name: 标签名称
    ///   - color: 标签颜色
    func addTag(name: String, color: TagColor = .blue) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 50 else {
            return
        }

        let tag = Tag(name: name, color: color)
        tags.append(tag)
        try? save()
    }

    /// 更新标签
    /// - Parameters:
    ///   - id: 标签 ID
    ///   - name: 新名称（可选）
    ///   - color: 新颜色（可选）
    func updateTag(id: UUID, name: String? = nil, color: TagColor? = nil) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else {
            return
        }

        if let name = name {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  name.count <= 50 else {
                return
            }
            tags[index].name = name
        }

        if let color = color {
            tags[index].color = color
        }

        try? save()
    }

    /// 删除标签
    /// - Parameter id: 标签 ID
    func deleteTag(id: UUID) {
        tags.removeAll { $0.id == id }

        // 同时从所有任务中移除该标签
        for index in todos.indices {
            todos[index].tagIds.removeAll { $0 == id }
        }

        try? save()
        saveState()
    }

    /// 为任务设置标签
    /// - Parameters:
    ///   - todoId: 任务 ID
    ///   - tagIds: 标签 ID 列表
    func setTodoTags(todoId: UUID, tagIds: [UUID]) {
        guard let index = todos.firstIndex(where: { $0.id == todoId }) else {
            return
        }

        todos[index].tagIds = tagIds
        todos[index].updatedAt = Date()
        try? save()
        saveState()
    }

    /// 为任务添加标签
    /// - Parameters:
    ///   - todoId: 任务 ID
    ///   - tagId: 标签 ID
    func addTagToTodo(todoId: UUID, tagId: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == todoId }),
              !todos[index].tagIds.contains(tagId) else {
            return
        }

        todos[index].tagIds.append(tagId)
        todos[index].updatedAt = Date()
        try? save()
        saveState()
    }

    /// 从任务移除标签
    /// - Parameters:
    ///   - todoId: 任务 ID
    ///   - tagId: 标签 ID
    func removeTagFromTodo(todoId: UUID, tagId: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == todoId }) else {
            return
        }

        todos[index].tagIds.removeAll { $0 == tagId }
        todos[index].updatedAt = Date()
        try? save()
        saveState()
    }

    /// 获取标签对象
    /// - Parameter id: 标签 ID
    /// - Returns: 标签对象（不存在时返回 nil）
    func tag(for id: UUID) -> Tag? {
        tags.first { $0.id == id }
    }
}

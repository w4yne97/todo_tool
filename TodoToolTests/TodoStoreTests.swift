import XCTest
@testable import TodoTool

/// TodoStore 持久化层单元测试
final class TodoStoreTests: XCTestCase {
    
    /// 测试用临时目录
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // 创建临时测试目录
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TodoStoreTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // 清理测试目录
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }
    
    // MARK: - 初始化测试
    
    /// 测试空目录初始化
    func testInitWithEmptyDirectory() {
        let store = TodoStore(dataDirectory: testDirectory)
        XCTAssertTrue(store.todos.isEmpty, "新建 Store 应没有任务")
    }
    
    /// 测试从已有数据文件加载
    func testLoadFromExistingFile() throws {
        // 准备测试数据
        let todo = Todo(title: "测试任务")
        let todoData = TodoData(version: 1, todos: [todo])
        let data = try todoData.encoded()
        let dataURL = testDirectory.appendingPathComponent("data.json")
        try data.write(to: dataURL)
        
        // 加载
        let store = TodoStore(dataDirectory: testDirectory)
        
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.todos.first?.title, "测试任务")
    }
    
    // MARK: - 保存测试
    
    /// 测试保存创建数据文件
    func testSaveCreatesDataFile() throws {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "新任务")
        
        let dataURL = testDirectory.appendingPathComponent("data.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataURL.path), "保存后应创建 data.json")
    }
    
    /// 测试保存创建备份文件
    func testSaveCreatesBackup() throws {
        let store = TodoStore(dataDirectory: testDirectory)
        
        // 第一次保存
        store.add(title: "任务1")
        
        // 第二次保存（触发备份）
        store.add(title: "任务2")
        
        let backupURL = testDirectory.appendingPathComponent("data.json.backup")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "第二次保存应创建 backup")
    }
    
    /// 测试从备份恢复
    func testRecoveryFromBackup() throws {
        // 准备备份文件
        let todo = Todo(title: "备份任务")
        let todoData = TodoData(version: 1, todos: [todo])
        let data = try todoData.encoded()
        let backupURL = testDirectory.appendingPathComponent("data.json.backup")
        try data.write(to: backupURL)
        
        // 主文件不存在，应从备份恢复
        let store = TodoStore(dataDirectory: testDirectory)
        
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.todos.first?.title, "备份任务")
    }
    
    /// 测试损坏的主文件使用备份恢复
    func testCorruptedMainFileRecovery() throws {
        // 写入损坏的主文件
        let dataURL = testDirectory.appendingPathComponent("data.json")
        try "invalid json".write(to: dataURL, atomically: true, encoding: .utf8)
        
        // 写入有效的备份文件
        let todo = Todo(title: "备份中的任务")
        let todoData = TodoData(version: 1, todos: [todo])
        let data = try todoData.encoded()
        let backupURL = testDirectory.appendingPathComponent("data.json.backup")
        try data.write(to: backupURL)
        
        // 加载时应从备份恢复
        let store = TodoStore(dataDirectory: testDirectory)
        
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.todos.first?.title, "备份中的任务")
    }
    
    // MARK: - CRUD 测试
    
    /// 测试添加任务
    func testAddTodo() {
        let store = TodoStore(dataDirectory: testDirectory)
        
        store.add(title: "新任务")
        
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.todos.first?.title, "新任务")
        XCTAssertFalse(store.todos.first?.isCompleted ?? true)
    }
    
    /// 测试添加多个任务的顺序（最新在前）
    func testAddTodosOrder() {
        let store = TodoStore(dataDirectory: testDirectory)
        
        store.add(title: "任务1")
        store.add(title: "任务2")
        store.add(title: "任务3")
        
        XCTAssertEqual(store.todos.count, 3)
        XCTAssertEqual(store.todos[0].title, "任务3") // 最新在最前
        XCTAssertEqual(store.todos[1].title, "任务2")
        XCTAssertEqual(store.todos[2].title, "任务1")
    }
    
    /// 测试空标题被拒绝
    func testAddEmptyTitleRejected() {
        let store = TodoStore(dataDirectory: testDirectory)
        
        store.add(title: "")
        store.add(title: "   ")
        
        XCTAssertTrue(store.todos.isEmpty, "空标题不应被添加")
    }
    
    /// 测试超长标题被拒绝
    func testAddOverlongTitleRejected() {
        let store = TodoStore(dataDirectory: testDirectory)
        let longTitle = String(repeating: "a", count: 201)
        
        store.add(title: longTitle)
        
        XCTAssertTrue(store.todos.isEmpty, "超过 200 字符的标题不应被添加")
    }
    
    /// 测试切换完成状态
    func testToggleComplete() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "测试任务")
        let id = store.todos.first!.id
        
        // 切换为完成
        store.toggle(id: id)
        XCTAssertTrue(store.todos.first!.isCompleted)
        XCTAssertNotNil(store.todos.first!.completedAt)
        
        // 切换回未完成
        store.toggle(id: id)
        XCTAssertFalse(store.todos.first!.isCompleted)
        XCTAssertNil(store.todos.first!.completedAt)
    }
    
    /// 测试切换更新 updatedAt
    func testToggleUpdatesTimestamp() throws {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "测试任务")
        let id = store.todos.first!.id
        let originalUpdatedAt = store.todos.first!.updatedAt
        
        // 等待一小段时间确保时间戳不同
        Thread.sleep(forTimeInterval: 0.01)
        
        store.toggle(id: id)
        
        XCTAssertGreaterThan(store.todos.first!.updatedAt, originalUpdatedAt)
    }
    
    /// 测试删除任务
    func testDeleteTodo() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "任务1")
        store.add(title: "任务2")
        let idToDelete = store.todos.first!.id
        
        store.delete(id: idToDelete)
        
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.todos.first?.title, "任务1")
    }
    
    /// 测试删除不存在的 ID 不崩溃
    func testDeleteNonExistentId() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "任务")
        
        store.delete(id: UUID()) // 不存在的 ID
        
        XCTAssertEqual(store.todos.count, 1, "删除不存在的 ID 不应影响现有数据")
    }
    
    /// 测试更新标题
    func testUpdateTitle() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "原标题")
        let id = store.todos.first!.id
        
        store.update(id: id, title: "新标题")
        
        XCTAssertEqual(store.todos.first?.title, "新标题")
    }
    
    /// 测试更新标题更新 updatedAt
    func testUpdateTitleUpdatesTimestamp() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "原标题")
        let id = store.todos.first!.id
        let originalUpdatedAt = store.todos.first!.updatedAt
        
        Thread.sleep(forTimeInterval: 0.01)
        
        store.update(id: id, title: "新标题")
        
        XCTAssertGreaterThan(store.todos.first!.updatedAt, originalUpdatedAt)
    }
    
    /// 测试更新为空标题被拒绝
    func testUpdateEmptyTitleRejected() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "原标题")
        let id = store.todos.first!.id
        
        store.update(id: id, title: "")
        
        XCTAssertEqual(store.todos.first?.title, "原标题", "空标题更新应被拒绝")
    }
    
    /// 测试更新为超长标题被拒绝
    func testUpdateOverlongTitleRejected() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "原标题")
        let id = store.todos.first!.id
        let longTitle = String(repeating: "a", count: 201)
        
        store.update(id: id, title: longTitle)
        
        XCTAssertEqual(store.todos.first?.title, "原标题", "超过 200 字符的标题更新应被拒绝")
    }
    
    /// 测试切换不存在的 ID 不崩溃
    func testToggleNonExistentId() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "任务")
        let originalCompleted = store.todos.first!.isCompleted
        
        store.toggle(id: UUID()) // 不存在的 ID
        
        XCTAssertEqual(store.todos.first?.isCompleted, originalCompleted, "切换不存在的 ID 不应影响现有数据")
    }
    
    /// 测试更新不存在的 ID 不崩溃
    func testUpdateNonExistentId() {
        let store = TodoStore(dataDirectory: testDirectory)
        store.add(title: "原标题")
        
        store.update(id: UUID(), title: "新标题") // 不存在的 ID
        
        XCTAssertEqual(store.todos.first?.title, "原标题", "更新不存在的 ID 不应影响现有数据")
    }
    
    // MARK: - 持久化验证
    
    /// 测试数据持久化后可重新加载
    func testPersistenceRoundTrip() throws {
        // 创建并保存
        let store1 = TodoStore(dataDirectory: testDirectory)
        store1.add(title: "持久化任务")
        store1.toggle(id: store1.todos.first!.id)
        
        // 使用新实例加载
        let store2 = TodoStore(dataDirectory: testDirectory)
        
        XCTAssertEqual(store2.todos.count, 1)
        XCTAssertEqual(store2.todos.first?.title, "持久化任务")
        XCTAssertTrue(store2.todos.first?.isCompleted ?? false)
        XCTAssertNotNil(store2.todos.first?.completedAt)
    }
}

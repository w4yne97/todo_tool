import XCTest
import XCTest
@testable import TodoTool

final class TodoModelTests: XCTestCase {
    
    // MARK: - Todo 创建测试
    
    func testTodoCreation() {
        let todo = Todo(title: "测试任务")
        
        XCTAssertFalse(todo.id.uuidString.isEmpty)
        XCTAssertEqual(todo.title, "测试任务")
        XCTAssertFalse(todo.isCompleted)
        XCTAssertNil(todo.completedAt)
        XCTAssertEqual(todo.createdAt, todo.updatedAt)
    }
    
    func testTodoCreationWithAllParameters() {
        let id = UUID()
        let now = Date()
        let todo = Todo(
            id: id,
            title: "完整参数任务",
            isCompleted: true,
            createdAt: now,
            completedAt: now,
            updatedAt: now
        )
        
        XCTAssertEqual(todo.id, id)
        XCTAssertEqual(todo.title, "完整参数任务")
        XCTAssertTrue(todo.isCompleted)
        XCTAssertEqual(todo.createdAt, now)
        XCTAssertEqual(todo.completedAt, now)
        XCTAssertEqual(todo.updatedAt, now)
    }
    
    // MARK: - JSON 序列化测试
    
    func testTodoEncoding() throws {
        let id = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let date = ISO8601DateFormatter().date(from: "2026-01-09T10:00:00Z")!
        
        let todo = Todo(
            id: id,
            title: "编码测试",
            isCompleted: false,
            createdAt: date,
            completedAt: nil,
            updatedAt: date
        )
        
        let data = try Todo.encoder.encode(todo)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"id\" : \"12345678-1234-1234-1234-123456789012\""))
        XCTAssertTrue(jsonString.contains("\"title\" : \"编码测试\""))
        XCTAssertTrue(jsonString.contains("\"isCompleted\" : false"))
        XCTAssertTrue(jsonString.contains("2026-01-09T10:00:00"))
    }
    
    func testTodoDecoding() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "解码测试",
            "isCompleted": true,
            "createdAt": "2026-01-09T10:00:00Z",
            "completedAt": "2026-01-09T14:30:00Z",
            "updatedAt": "2026-01-09T14:30:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let todo = try Todo.decoder.decode(Todo.self, from: data)
        
        XCTAssertEqual(todo.id.uuidString, "12345678-1234-1234-1234-123456789012")
        XCTAssertEqual(todo.title, "解码测试")
        XCTAssertTrue(todo.isCompleted)
        XCTAssertNotNil(todo.completedAt)
    }
    
    func testTodoRoundTrip() throws {
        let original = Todo(
            title: "往返测试",
            isCompleted: true,
            completedAt: Date()
        )
        
        let data = try Todo.encoder.encode(original)
        let decoded = try Todo.decoder.decode(Todo.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.isCompleted, decoded.isCompleted)
        // 日期比较允许毫秒级误差（JSON 编码可能有精度损失）
        if let originalCompleted = original.completedAt,
           let decodedCompleted = decoded.completedAt {
            XCTAssertEqual(originalCompleted.timeIntervalSince1970, 
                          decodedCompleted.timeIntervalSince1970, 
                          accuracy: 0.001)
        }
    }
    
    // MARK: - 日期格式测试
    
    func testDateDecodingWithFractionalSeconds() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "毫秒测试",
            "isCompleted": false,
            "createdAt": "2026-01-09T10:00:00.123Z",
            "completedAt": null,
            "updatedAt": "2026-01-09T10:00:00.123Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let todo = try Todo.decoder.decode(Todo.self, from: data)
        
        XCTAssertEqual(todo.title, "毫秒测试")
    }
    
    func testDateDecodingWithoutFractionalSeconds() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "无毫秒测试",
            "isCompleted": false,
            "createdAt": "2026-01-09T10:00:00Z",
            "completedAt": null,
            "updatedAt": "2026-01-09T10:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let todo = try Todo.decoder.decode(Todo.self, from: data)
        
        XCTAssertEqual(todo.title, "无毫秒测试")
    }
    
    // MARK: - TodoData 测试
    
    func testTodoDataEmpty() {
        let emptyData = TodoData.empty
        
        XCTAssertEqual(emptyData.version, 1)
        XCTAssertTrue(emptyData.todos.isEmpty)
    }
    
    func testTodoDataEncoding() throws {
        let todo = Todo(title: "容器测试")
        let todoData = TodoData(version: 1, todos: [todo])
        
        let data = try todoData.encoded()
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"version\" : 1"))
        XCTAssertTrue(jsonString.contains("\"todos\""))
        XCTAssertTrue(jsonString.contains("\"title\" : \"容器测试\""))
    }
    
    func testTodoDataRoundTrip() throws {
        let todos = [
            Todo(title: "任务一"),
            Todo(title: "任务二", isCompleted: true, completedAt: Date())
        ]
        let original = TodoData(version: 1, todos: todos)
        
        let data = try original.encoded()
        let decoded = try TodoData.decoded(from: data)
        
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.todos.count, 2)
        XCTAssertEqual(decoded.todos[0].title, "任务一")
        XCTAssertEqual(decoded.todos[1].title, "任务二")
        XCTAssertTrue(decoded.todos[1].isCompleted)
    }
    
    // MARK: - Equatable 测试
    
    func testTodoEquatable() {
        let id = UUID()
        let date = Date()
        let todo1 = Todo(id: id, title: "相同", createdAt: date, updatedAt: date)
        let todo2 = Todo(id: id, title: "相同", createdAt: date, updatedAt: date)
        
        XCTAssertEqual(todo1, todo2)
    }
    
    func testTodoNotEqualDifferentId() {
        let todo1 = Todo(title: "任务")
        let todo2 = Todo(title: "任务")
        
        XCTAssertNotEqual(todo1, todo2) // 不同的 UUID
    }
    
    // MARK: - 优先级测试
    
    func testTodoWithPriority() {
        let todo = Todo(title: "高优先级任务", priority: .high)
        
        XCTAssertEqual(todo.priority, .high)
    }
    
    func testPriorityEncodingDecoding() throws {
        let todo = Todo(title: "中优先级任务", priority: .medium)
        
        let data = try Todo.encoder.encode(todo)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"priority\" : \"medium\""))
        
        let decoded = try Todo.decoder.decode(Todo.self, from: data)
        XCTAssertEqual(decoded.priority, .medium)
    }
    
    func testBackwardCompatibility() throws {
        // 模拟旧版本数据（无 priority 字段）
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "旧版任务",
            "isCompleted": false,
            "createdAt": "2026-01-09T10:00:00Z",
            "completedAt": null,
            "updatedAt": "2026-01-09T10:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let todo = try Todo.decoder.decode(Todo.self, from: data)
        
        XCTAssertEqual(todo.title, "旧版任务")
        XCTAssertEqual(todo.priority, .none) // 默认为无优先级
    }
    
    func testPriorityDisplayName() {
        XCTAssertEqual(Priority.none.displayName, "无")
        XCTAssertEqual(Priority.low.displayName, "低")
        XCTAssertEqual(Priority.medium.displayName, "中")
        XCTAssertEqual(Priority.high.displayName, "高")
    }

    func testIsOverdueAndDueSoon() {
        let overdue = Todo(title: "过期", dueDate: Date().addingTimeInterval(-3600))
        XCTAssertTrue(overdue.isOverdue)
        let dueSoon = Todo(title: "临近", dueDate: Date().addingTimeInterval(3600))
        XCTAssertFalse(dueSoon.isOverdue)
        XCTAssertTrue(dueSoon.isDueSoon)
    }

    // MARK: - 四象限分类测试

    func testQuadrantEnumProperties() {
        // 测试象限基本属性
        XCTAssertEqual(Quadrant.urgentImportant.shortName, "紧急重要")
        XCTAssertEqual(Quadrant.notUrgentImportant.shortName, "重要")
        XCTAssertEqual(Quadrant.urgentNotImportant.shortName, "紧急")
        XCTAssertEqual(Quadrant.notUrgentNotImportant.shortName, "其他")
    }

    func testQuadrantFromImportanceAndUrgency() {
        // 测试从重要性和紧急性创建象限
        XCTAssertEqual(Quadrant.from(isImportant: true, isUrgent: true), .urgentImportant)
        XCTAssertEqual(Quadrant.from(isImportant: true, isUrgent: false), .notUrgentImportant)
        XCTAssertEqual(Quadrant.from(isImportant: false, isUrgent: true), .urgentNotImportant)
        XCTAssertEqual(Quadrant.from(isImportant: false, isUrgent: false), .notUrgentNotImportant)
    }

    func testQuadrantIsImportantAndIsUrgent() {
        // 测试象限的重要性和紧急性属性
        XCTAssertTrue(Quadrant.urgentImportant.isImportant)
        XCTAssertTrue(Quadrant.urgentImportant.isUrgent)

        XCTAssertTrue(Quadrant.notUrgentImportant.isImportant)
        XCTAssertFalse(Quadrant.notUrgentImportant.isUrgent)

        XCTAssertFalse(Quadrant.urgentNotImportant.isImportant)
        XCTAssertTrue(Quadrant.urgentNotImportant.isUrgent)

        XCTAssertFalse(Quadrant.notUrgentNotImportant.isImportant)
        XCTAssertFalse(Quadrant.notUrgentNotImportant.isUrgent)
    }

    func testQuadrantGridOrder() {
        // 测试网格排列顺序（2x2 布局）
        let order = Quadrant.gridOrder
        XCTAssertEqual(order.count, 4)
        XCTAssertEqual(order[0], .urgentImportant)       // 左上
        XCTAssertEqual(order[1], .notUrgentImportant)    // 右上
        XCTAssertEqual(order[2], .urgentNotImportant)    // 左下
        XCTAssertEqual(order[3], .notUrgentNotImportant) // 右下
    }

    func testTodoIsImportant() {
        // 高优先级 → 重要
        let highPriority = Todo(title: "高优先级", priority: .high)
        XCTAssertTrue(highPriority.isImportant)

        // 中优先级 → 重要
        let mediumPriority = Todo(title: "中优先级", priority: .medium)
        XCTAssertTrue(mediumPriority.isImportant)

        // 低优先级 → 不重要
        let lowPriority = Todo(title: "低优先级", priority: .low)
        XCTAssertFalse(lowPriority.isImportant)

        // 无优先级 → 不重要
        let noPriority = Todo(title: "无优先级", priority: .none)
        XCTAssertFalse(noPriority.isImportant)
    }

    func testTodoIsUrgent() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 今天到期 → 紧急
        let dueToday = Todo(title: "今天到期", dueDate: today)
        XCTAssertTrue(dueToday.isUrgent)

        // 过期 → 紧急
        let overdue = Todo(title: "已过期", dueDate: today.addingTimeInterval(-86400))
        XCTAssertTrue(overdue.isUrgent)

        // 明天到期 → 不紧急
        let dueTomorrow = Todo(title: "明天到期", dueDate: today.addingTimeInterval(86400))
        XCTAssertFalse(dueTomorrow.isUrgent)

        // 无到期日 → 不紧急
        let noDueDate = Todo(title: "无到期日")
        XCTAssertFalse(noDueDate.isUrgent)
    }

    func testTodoQuadrantClassification() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = today.addingTimeInterval(86400)

        // Q1: 重要且紧急（高优先级 + 今天到期）
        let q1 = Todo(title: "Q1任务", priority: .high, dueDate: today)
        XCTAssertEqual(q1.quadrant, .urgentImportant)

        // Q2: 重要但不紧急（高优先级 + 明天到期）
        let q2 = Todo(title: "Q2任务", priority: .high, dueDate: tomorrow)
        XCTAssertEqual(q2.quadrant, .notUrgentImportant)

        // Q3: 不重要但紧急（低优先级 + 今天到期）
        let q3 = Todo(title: "Q3任务", priority: .low, dueDate: today)
        XCTAssertEqual(q3.quadrant, .urgentNotImportant)

        // Q4: 不重要且不紧急（低优先级 + 明天到期）
        let q4 = Todo(title: "Q4任务", priority: .low, dueDate: tomorrow)
        XCTAssertEqual(q4.quadrant, .notUrgentNotImportant)

        // 无优先级无到期日 → Q4
        let defaultTodo = Todo(title: "默认任务")
        XCTAssertEqual(defaultTodo.quadrant, .notUrgentNotImportant)
    }
}

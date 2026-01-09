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
}

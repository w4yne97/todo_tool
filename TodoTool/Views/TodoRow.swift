// ==================== 单行任务视图 ====================
// 显示单个待办事项，包含完成状态、标题、完成时间

import SwiftUI

struct TodoRow: View {
    /// 待办事项数据
    let todo: Todo
    
    /// 切换完成状态的回调
    var onToggle: () -> Void
    
    /// 日期格式化器
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // 完成状态图标
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // 任务标题
            Text(todo.title)
                .strikethrough(todo.isCompleted, color: .secondary)
                .foregroundColor(todo.isCompleted ? .secondary : .primary)
                .lineLimit(2)
            
            Spacer()
            
            // 已完成任务显示完成时间
            if todo.isCompleted, let completedAt = todo.completedAt {
                Text(Self.formatDate(completedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 确保整行可点击
    }
    
    /// 格式化日期，今天的只显示时间，其他显示完整日期
    private static func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return timeFormatter.string(from: date)
        } else {
            return dateFormatter.string(from: date)
        }
    }
}

#Preview("未完成") {
    TodoRow(
        todo: Todo(title: "买菜"),
        onToggle: {}
    )
    .padding()
}

#Preview("已完成") {
    TodoRow(
        todo: Todo(
            title: "完成项目报告",
            isCompleted: true,
            completedAt: Date()
        ),
        onToggle: {}
    )
    .padding()
}

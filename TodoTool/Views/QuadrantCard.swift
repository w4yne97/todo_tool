// ==================== 象限卡片组件 ====================
// 四象限视图中的单个象限卡片，显示该象限的任务列表

import SwiftUI

/// 象限卡片视图
/// 显示单个象限的标题、任务计数和任务列表
struct QuadrantCard: View {
    /// 象限类型
    let quadrant: Quadrant
    /// 该象限的任务列表
    let todos: [Todo]
    /// 任务点击回调
    var onToggle: ((UUID) -> Void)?
    /// 任务选中回调
    var onSelect: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题栏
            headerView

            // 任务列表或空状态
            if todos.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(quadrant.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        HStack {
            // 颜色指示器
            Circle()
                .fill(quadrant.color)
                .frame(width: 10, height: 10)

            // 象限名称
            Text(quadrant.shortName)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // 任务计数
            Text("\(todos.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 4) {
            Spacer()
            Text("暂无任务")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(quadrant.actionHint)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    /// 任务列表
    private var taskListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(todos) { todo in
                    QuadrantTodoRow(
                        todo: todo,
                        onToggle: { onToggle?(todo.id) },
                        onSelect: { onSelect?(todo.id) }
                    )
                }
            }
        }
        .frame(minHeight: 80)
    }

    /// 卡片背景
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.primary.opacity(0.03))
    }
}

// MARK: - 象限任务行

/// 象限视图中的简化任务行
struct QuadrantTodoRow: View {
    let todo: Todo
    var onToggle: (() -> Void)?
    var onSelect: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // 完成状态图标
            Button(action: { onToggle?() }) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            // 优先级指示器
            if todo.priority != .none && !todo.isCompleted {
                Circle()
                    .fill(todo.priority.color)
                    .frame(width: 6, height: 6)
            }

            // 任务标题
            Text(todo.title)
                .font(.subheadline)
                .foregroundColor(todo.isCompleted ? .secondary : .primary)
                .strikethrough(todo.isCompleted)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // 到期日期标签（如果有）
            if let dueDate = todo.dueDate {
                dueDateLabel(dueDate)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect?()
        }
    }

    /// 到期日期标签
    private func dueDateLabel(_ date: Date) -> some View {
        let isOverdue = todo.isOverdue
        let isDueSoon = todo.isDueSoon

        return Text(formatDate(date))
            .font(.caption2)
            .foregroundColor(isOverdue ? .white : (isDueSoon ? .orange : .secondary))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isOverdue ? Color.red : Color.clear)
            .clipShape(Capsule())
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview("四象限卡片") {
    HStack(spacing: 16) {
        QuadrantCard(
            quadrant: .urgentImportant,
            todos: [
                Todo(title: "紧急任务1", priority: .high, dueDate: Date()),
                Todo(title: "紧急任务2", priority: .medium, dueDate: Date())
            ]
        )

        QuadrantCard(
            quadrant: .notUrgentNotImportant,
            todos: []
        )
    }
    .padding()
    .frame(width: 600, height: 300)
}

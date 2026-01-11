import SwiftUI

struct QuadrantCard: View {
    let quadrant: Quadrant
    let todos: [Todo]
    var onToggle: ((UUID) -> Void)?
    var onSelect: ((UUID) -> Void)?
    
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
                .opacity(0.5)

            ZStack {
                if todos.isEmpty {
                    emptyStateView
                } else {
                    taskListView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            quadrant.color.opacity(0.4),
                            quadrant.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: quadrant.color.opacity(isHovered ? 0.15 : 0.05),
            radius: isHovered ? 16 : 8,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: quadrant.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(quadrant.color)
                .frame(width: 32, height: 32)
                .background(quadrant.color.opacity(0.1))
                .clipShape(Circle())
            
            Text(quadrant.shortName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Text("\(todos.count)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: quadrant.iconName)
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [quadrant.color.opacity(0.2), quadrant.color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, 4)
            
            Text(quadrant.actionHint)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(todos) { todo in
                    QuadrantTodoRow(
                        todo: todo,
                        onToggle: { onToggle?(todo.id) },
                        onSelect: { onSelect?(todo.id) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(12)
        }
    }
}

struct QuadrantTodoRow: View {
    let todo: Todo
    var onToggle: (() -> Void)?
    var onSelect: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: { onToggle?() }) {
                ZStack {
                    Circle()
                        .stroke(
                            todo.isCompleted ? Color.green : Color.secondary.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)
                    
                    if todo.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 14))
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(1)
                
                if let dueDate = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(formatDate(dueDate))
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(dateColor(for: todo))
                }
            }

            Spacer()
            
            if todo.priority != .none && !todo.isCompleted {
                Circle()
                    .fill(todo.priority.color)
                    .frame(width: 6, height: 6)
                    .shadow(color: todo.priority.color.opacity(0.5), radius: 2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? 0.1 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSelect?()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func dateColor(for todo: Todo) -> Color {
        if todo.isOverdue { return .red }
        if todo.isDueSoon { return .orange }
        return .secondary
    }
}

#Preview("四象限卡片") {
    ZStack {
        Color.gray.opacity(0.1)
        HStack(spacing: 20) {
            QuadrantCard(
                quadrant: .urgentImportant,
                todos: [
                    Todo(title: "完成季度报告", priority: .high, dueDate: Date()),
                    Todo(title: "紧急客户会议", priority: .high, dueDate: Date().addingTimeInterval(3600)),
                    Todo(title: "修复线上 Bug", priority: .medium, dueDate: Date())
                ]
            )
            
            QuadrantCard(
                quadrant: .notUrgentNotImportant,
                todos: []
            )
        }
        .padding(40)
        .frame(width: 800, height: 500)
    }
}

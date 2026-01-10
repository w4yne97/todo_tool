// ==================== 单行任务视图 ====================
// 显示单个待办事项，包含完成状态、标题、完成时间
// 支持双击或 Enter 编辑标题，Enter 确认，Esc 取消

import SwiftUI

struct TodoRow: View {
    /// 待办事项数据
    let todo: Todo

    /// 切换完成状态的回调
    var onToggle: () -> Void

    /// 更新标题的回调
    var onUpdate: ((String) -> Void)?

    /// 删除任务的回调（当标题清空时触发）
    var onDelete: (() -> Void)?

    /// 编辑结束回调（用于恢复 List 选中状态）
    var onEditEnd: (() -> Void)?

    /// 设置优先级回调
    var onSetPriority: ((Priority) -> Void)?

    /// 设置到期日期回调
    var onSetDueDate: ((Date?) -> Void)?

    /// 可用标签列表（用于显示和管理）
    var availableTags: [Tag] = []

    /// 设置标签回调
    var onToggleTag: ((UUID) -> Void)?

    /// 外部控制的编辑状态绑定
    @Binding var isEditingExternally: Bool

    /// 内部编辑中的标题
    @State private var editingTitle = ""

    /// 焦点状态
    @FocusState private var isFocused: Bool

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

    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            priorityMenu

            // 完成状态图标 - 带弹性缩放动画
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(todo.isCompleted ? .green : .secondary)
                .scaleEffect(todo.isCompleted ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: todo.isCompleted)
                .onTapGesture(perform: onToggle)

            // 任务标题（编辑模式 vs 显示模式）- 带淡入淡出动画
            if isEditingExternally {
                TextField("任务标题", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(confirmEdit)
                    .onExitCommand(perform: cancelEdit)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .strikethrough(todo.isCompleted, color: .secondary)
                        .foregroundColor(todo.isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: todo.isCompleted)

                    // 标签徽章
                    if !todo.tagIds.isEmpty {
                        tagBadgesView
                    }
                }
            }

            Spacer()

            // 到期日期显示 - 不同状态不同颜色
            if let dueDate = todo.dueDate, !todo.isCompleted {
                dueDateLabel(dueDate)
            }

            // 已完成任务显示完成时间 - 带滑入动画
            if todo.isCompleted, let completedAt = todo.completedAt {
                Text(Self.formatDate(completedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
            }
        }
        // 右键菜单
        .contextMenu {
            // 编辑选项
            if onUpdate != nil {
                Button("编辑") {
                    startEditing()
                }
                Divider()
            }
            dueDateContextMenu
            tagsContextMenu
        }
        .animation(.easeInOut(duration: 0.2), value: todo.priority)
        .padding(.vertical, 4)
        // 让整行都可以响应点击（用于 List 选中），必须在 padding 之后
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isEditingExternally)
        .onChange(of: isEditingExternally) { _, newValue in
            if newValue {
                startEditing()
            }
        }
        // 监听焦点变化，点击外部时确认编辑
        .onChange(of: isFocused) { _, newValue in
            if !newValue && isEditingExternally {
                confirmEdit()
            }
        }
    }

    @ViewBuilder
    private var priorityMenu: some View {
        // 使用 ZStack 将可见圆点与菜单触发器分离
        // 圆点直接渲染（不作为 Menu label），菜单使用透明触发器
        let color: Color = todo.priority == .none ? .gray.opacity(0.5) : todo.priority.color

        ZStack {
            // 1. 可见的颜色圆点 - 直接渲染，不受 Menu 样式影响
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            // 2. 透明的菜单触发器（仅覆盖圆点区域）
            if let onSetPriority = onSetPriority {
                Menu {
                    ForEach(Priority.orderedCases, id: \.self) { priority in
                        Button {
                            onSetPriority(priority)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(priority == .none ? Color.gray.opacity(0.5) : priority.color)
                                    .frame(width: 8, height: 8)
                                Text(priority.displayName)
                                if todo.priority == priority {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    // 透明触发区域 - 仅限圆点大小
                    Color.clear
                        .frame(width: 14, height: 14)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
        }
        .frame(width: 14, height: 14)
        .help("优先级：\(todo.priority.displayName)")
    }

    private struct PriorityBadgeView: View {
        let priority: Priority

        var body: some View {
            // 使用 Canvas 进行像素级绘制，完全绕过 macOS Menu 的样式覆盖
            let color: Color = priority == .none ? .gray.opacity(0.5) : priority.color
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Circle().path(in: rect), with: .color(color))
            }
            .frame(width: 10, height: 10)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .help("优先级：\(priority.displayName)")
        }
    }

    // MARK: - 到期日期视图

    /// 到期日期标签
    @ViewBuilder
    private func dueDateLabel(_ dueDate: Date) -> some View {
        let dueDateColor: Color = {
            if todo.isOverdue {
                return .red
            } else if todo.isDueSoon {
                return .orange
            } else {
                return .secondary
            }
        }()

        HStack(spacing: 4) {
            Image(systemName: todo.isOverdue ? "exclamationmark.circle" : "calendar")
                .font(.caption2)
            Text(formatDueDate(dueDate))
                .font(.caption)
        }
        .foregroundColor(dueDateColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(dueDateColor.opacity(0.1))
        .cornerRadius(4)
    }

    /// 格式化到期日期
    private func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "今天"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "明天"
        } else {
            return Self.dueDateFormatter.string(from: date)
        }
    }

    /// 到期日期右键菜单
    @ViewBuilder
    private var dueDateContextMenu: some View {
        if let onSetDueDate = onSetDueDate {
            Menu("设置到期日期") {
                Button("今天") {
                    onSetDueDate(Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400 - 1))
                }
                Button("明天") {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                    onSetDueDate(Calendar.current.startOfDay(for: tomorrow).addingTimeInterval(86400 - 1))
                }
                Button("下周") {
                    let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
                    onSetDueDate(Calendar.current.startOfDay(for: nextWeek).addingTimeInterval(86400 - 1))
                }
                Divider()
                if todo.dueDate != nil {
                    Button("清除到期日期") {
                        onSetDueDate(nil)
                    }
                }
            }
        }
    }

    // MARK: - 标签视图

    /// 标签徽章视图
    @ViewBuilder
    private var tagBadgesView: some View {
        HStack(spacing: 4) {
            ForEach(todo.tagIds.prefix(3), id: \.self) { tagId in
                if let tag = availableTags.first(where: { $0.id == tagId }) {
                    Text(tag.name)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(tag.color.color.opacity(0.2))
                        .foregroundColor(tag.color.color)
                        .cornerRadius(3)
                }
            }
            if todo.tagIds.count > 3 {
                Text("+\(todo.tagIds.count - 3)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// 标签右键菜单
    @ViewBuilder
    private var tagsContextMenu: some View {
        if let onToggleTag = onToggleTag, !availableTags.isEmpty {
            Menu("标签") {
                ForEach(availableTags) { tag in
                    Button {
                        onToggleTag(tag.id)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(tag.color.color)
                                .frame(width: 8, height: 8)
                            Text(tag.name)
                            if todo.tagIds.contains(tag.id) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 编辑操作

    /// 开始编辑
    private func startEditing() {
        editingTitle = todo.title
        isEditingExternally = true
        // 延迟设置焦点，确保 TextField 已渲染
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    }

    /// 确认编辑
    private func confirmEdit() {
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle.isEmpty {
            // 标题清空，删除任务
            onDelete?()
        } else if newTitle != todo.title {
            onUpdate?(newTitle)
        }
        isEditingExternally = false
        isFocused = false
        // 通知编辑结束
        onEditEnd?()
    }

    /// 取消编辑
    private func cancelEdit() {
        editingTitle = todo.title
        isEditingExternally = false
        isFocused = false
        // 通知编辑结束
        onEditEnd?()
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
        onToggle: {},
        onUpdate: { print("更新: \($0)") },
        onDelete: { print("删除") },
        onEditEnd: { print("编辑结束") },
        onSetPriority: { print("设置优先级: \($0)") },
        onSetDueDate: { print("设置到期日期: \(String(describing: $0))") },
        isEditingExternally: .constant(false)
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
        onToggle: {},
        onUpdate: nil,
        onDelete: nil,
        onEditEnd: nil,
        onSetPriority: nil,
        onSetDueDate: nil,
        isEditingExternally: .constant(false)
    )
    .padding()
}

#Preview("高优先级 + 即将到期") {
    TodoRow(
        todo: Todo(
            title: "紧急任务",
            priority: .high,
            dueDate: Date().addingTimeInterval(3600) // 1小时后到期
        ),
        onToggle: {},
        onUpdate: nil,
        onDelete: nil,
        onEditEnd: nil,
        onSetPriority: { print("设置优先级: \($0)") },
        onSetDueDate: { print("设置到期日期: \(String(describing: $0))") },
        isEditingExternally: .constant(false)
    )
    .padding()
}

#Preview("已过期任务") {
    TodoRow(
        todo: Todo(
            title: "已过期任务",
            priority: .medium,
            dueDate: Date().addingTimeInterval(-86400) // 1天前过期
        ),
        onToggle: {},
        onUpdate: nil,
        onDelete: nil,
        onEditEnd: nil,
        onSetPriority: nil,
        onSetDueDate: nil,
        isEditingExternally: .constant(false)
    )
    .padding()
}

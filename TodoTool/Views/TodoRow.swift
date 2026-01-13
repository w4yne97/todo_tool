// ==================== 单行任务视图 ====================
// 显示单个待办事项，包含完成状态、标题、完成时间
// 支持双击或 Enter 编辑标题，Enter 确认，Esc 取消

import SwiftUI

struct TodoRow: View {
    // MARK: - Properties
    let todo: Todo
    var onToggle: () -> Void
    var onUpdate: ((String) -> Void)?
    var onUpdateDetail: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onEditEnd: (() -> Void)?
    var onSelect: (() -> Void)?
    var onSetPriority: ((Priority) -> Void)?
    var onSetDueDate: ((Date?) -> Void)?
    var availableTags: [Tag] = []
    var onToggleTag: ((UUID) -> Void)?
    @Binding var isEditingExternally: Bool

    // MARK: - State
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var editingTitle = ""
    @State private var editingDetail = ""
    @State private var showDatePicker = false
    @State private var tempDate = Date()
    
    @FocusState private var isFocused: Bool
    @FocusState private var isDetailFocused: Bool

    // MARK: - Date Formatters
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 1. Left Column: Status & Priority
            HStack(alignment: .center, spacing: 6) {
                // Priority Menu
                priorityMenu
                    .opacity(isHovering || todo.priority != .none ? 1 : 0.5)
                
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(todo.isCompleted ? Color.green.gradient : Color.secondary.gradient)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(todo.isCompleted ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: todo.isCompleted)
            }
            .padding(.top, 3)

            // 2. Center Column: Content
            VStack(alignment: .leading, spacing: 4) {
                if isEditingExternally {
                    // Unified Editing Interface
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Task Title", text: $editingTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .focused($isFocused)
                            .onSubmit(confirmEdit)
                            .onExitCommand(perform: cancelEdit)
                        
                        Divider()
                            .opacity(0.5)
                        
                        TextEditor(text: $editingDetail)
                            .font(.body)
                            .scrollContentBackground(.hidden) // Hide default background
                            .frame(minHeight: 60, maxHeight: 120)
                            .padding(.horizontal, 8) // TextEditor has some internal padding
                            .padding(.vertical, 8)
                            .focused($isDetailFocused)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                } else {
                    // Display Mode
                    HStack(alignment: .firstTextBaseline) {
                        Text(todo.title)
                            .font(.system(size: 15, weight: .medium))
                            .strikethrough(todo.isCompleted)
                            .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                            .lineLimit(2)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded {
                                        onSelect?()
                                        if !todo.detail.isEmpty {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                isExpanded.toggle()
                                            }
                                        }
                                    }
                            )
                        
                        // Tags (Inline)
                        if !todo.tagIds.isEmpty {
                            tagBadgesView
                        }
                    }

                    // Description Area
                    if !todo.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            if isExpanded {
                                Text(todo.detail)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text(todo.detail)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .padding(.top, 4)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect?()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)

            // 3. Right Column: Metadata & Actions
            if !isEditingExternally {
                VStack(alignment: .trailing, spacing: 2) {
                    if let dueDate = todo.dueDate, !todo.isCompleted {
                        dateBadge(for: dueDate)
                            .onTapGesture {
                                prepareDatePicker()
                            }
                    } else if todo.dueDate == nil && isHovering && !todo.isCompleted {
                         Button {
                             prepareDatePicker()
                         } label: {
                             Image(systemName: "calendar.badge.plus")
                                 .font(.system(size: 14))
                                 .foregroundStyle(.secondary.opacity(0.5))
                         }
                         .buttonStyle(.plain)
                         .transition(.opacity)
                    }
                    
                    if todo.isCompleted, let completedAt = todo.completedAt {
                        Text("完成于 " + Self.timeFormatter.string(from: completedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering || isExpanded ? .regularMaterial : .ultraThinMaterial)
                .opacity(isHovering || isExpanded ? 1 : 0.01)
        }
        .overlay {
            if isHovering {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            if onUpdate != nil {
                Button("编辑") { startEditing() }
                Divider()
            }
            dueDateContextMenu
            tagsContextMenu
        }
        .popover(isPresented: $showDatePicker) {
            if let onSetDueDate = onSetDueDate {
                datePickerView(onSetDueDate: onSetDueDate)
            }
        }
        .onChange(of: isEditingExternally) { _, newValue in
            if newValue { startEditing() }
        }
        .onChange(of: isFocused) { _, _ in handleFocusChange() }
        .onChange(of: isDetailFocused) { _, _ in handleFocusChange() }
    }

    // MARK: - Subviews & Components

    @ViewBuilder
    private func dateBadge(for date: Date) -> some View {
        let isOverdue = todo.isOverdue
        let isDueSoon = todo.isDueSoon
        let hasSpecificTime = !isEndOfDay(date)
        
        let badgeColor: Color = isOverdue ? .red : (isDueSoon ? .orange : .blue)
        let displayColor = isOverdue || isDueSoon ? badgeColor : .secondary
        
        HStack(spacing: 4) {
            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "calendar")
                .symbolRenderingMode(.hierarchical)
                .font(.caption2)
            
            HStack(spacing: 3) {
                Text(formatDate(date))
                    .fontWeight(.medium)
                
                if hasSpecificTime {
                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(Self.timeFormatter.string(from: date))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            Capsule()
                .fill(displayColor.opacity(0.1))
        }
        .overlay {
            Capsule()
                .stroke(displayColor.opacity(0.2), lineWidth: 1)
        }
        .foregroundStyle(displayColor)
    }
    
    private var priorityMenu: some View {
        let color: Color = todo.priority == .none ? .gray.opacity(0.3) : todo.priority.color
        
        return ZStack {
             Circle()
                 .fill(color)
                 .frame(width: 8, height: 8)
            
             if let onSetPriority = onSetPriority {
                 Menu {
                     ForEach(Priority.orderedCases, id: \.self) { priority in
                         Button { onSetPriority(priority) } label: {
                             HStack {
                                 Text(priority.displayName)
                                 if todo.priority == priority {
                                     Image(systemName: "checkmark")
                                 }
                             }
                         }
                     }
                 } label: {
                     Color.clear.frame(width: 16, height: 16)
                 }
                 .menuStyle(.borderlessButton)
                 .menuIndicator(.hidden)
             }
        }
        .frame(width: 16, height: 16)
        .help("优先级：\(todo.priority.displayName)")
    }

    @ViewBuilder
    private var tagBadgesView: some View {
        HStack(spacing: 4) {
            ForEach(todo.tagIds.prefix(3), id: \.self) { tagId in
                if let tag = availableTags.first(where: { $0.id == tagId }) {
                    Text(tag.name)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(tag.color.color.opacity(0.15))
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
    
    @ViewBuilder
    private var dueDateContextMenu: some View {
        if let onSetDueDate = onSetDueDate {
            Menu("设置到期日期") {
                Button("今天") { setQuickDueDate(daysFromToday: 0, onSetDueDate: onSetDueDate) }
                Button("明天") { setQuickDueDate(daysFromToday: 1, onSetDueDate: onSetDueDate) }
                Button("下周") { setQuickDueDate(daysFromToday: 7, onSetDueDate: onSetDueDate) }
                Divider()
                Button("选择日期...") {
                    prepareDatePicker()
                }
                if todo.dueDate != nil {
                    Divider()
                    Button("清除到期日期") { onSetDueDate(nil) }
                }
            }
        }
    }
    
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
    
    private func datePickerView(onSetDueDate: @escaping (Date?) -> Void) -> some View {
        VStack(spacing: 0) {
            // 1. Header with shortcut buttons
            HStack(spacing: 8) {
                quickDateButton(label: "今天", days: 0, onSetDueDate: onSetDueDate)
                quickDateButton(label: "明天", days: 1, onSetDueDate: onSetDueDate)
                quickDateButton(label: "下周", days: 7, onSetDueDate: onSetDueDate)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // 2. Graphical Calendar
            DatePicker(
                "选择日期",
                selection: $tempDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // 3. Footer actions
            HStack {
                Button(action: {
                    onSetDueDate(nil)
                    showDatePicker = false
                }) {
                    Text("清除")
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("取消") {
                    showDatePicker = false
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                
                Button("确定") {
                    onSetDueDate(tempDate)
                    showDatePicker = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    private func quickDateButton(label: String, days: Int, onSetDueDate: @escaping (Date?) -> Void) -> some View {
        Button(action: {
            let start = Calendar.current.startOfDay(for: Date())
            let target = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
            onSetDueDate(endOfDay(for: target))
            showDatePicker = false
        }) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic Helpers

    private func handleFocusChange() {
        if !isFocused && !isDetailFocused && isEditingExternally {
            confirmEdit()
        }
    }
    
    private func startEditing() {
        editingTitle = todo.title
        editingDetail = todo.detail
        isEditingExternally = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    }
    
    private func confirmEdit() {
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newDetail = editingDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle.isEmpty {
            onDelete?()
        } else {
            if newTitle != todo.title { onUpdate?(newTitle) }
            if newDetail != todo.detail { onUpdateDetail?(newDetail) }
        }
        isEditingExternally = false
        isFocused = false
        onEditEnd?()
    }

    private func cancelEdit() {
        isEditingExternally = false
        isFocused = false
        onEditEnd?()
    }
    
    private func prepareDatePicker() {
        tempDate = todo.dueDate ?? Date()
        showDatePicker = true
    }
    
    private func endOfDay(for date: Date) -> Date {
        let start = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
    
    private func setQuickDueDate(daysFromToday: Int, onSetDueDate: @escaping (Date?) -> Void) {
        let start = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.date(byAdding: .day, value: daysFromToday, to: start) ?? start
        onSetDueDate(endOfDay(for: target))
    }
    
    private func isEndOfDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour == 23 && minute == 59
    }
    
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInTomorrow(date) { return "明天" }
        
        let formatter = DateFormatter()
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "yyyy年M月d日"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Previews
#Preview("任务列表") {
    VStack(spacing: 20) {
        TodoRow(
            todo: Todo(title: "常规任务", detail: "这是一个包含描述的常规任务"),
            onToggle: {}, isEditingExternally: .constant(false)
        )
        
        TodoRow(
            todo: Todo(title: "重要且紧急", detail: "必须在今天完成的项目报告\n包含多行详细说明", priority: .high, dueDate: Date()),
            onToggle: {}, isEditingExternally: .constant(false)
        )
        
        TodoRow(
            todo: Todo(title: "已完成任务", isCompleted: true, completedAt: Date()),
            onToggle: {}, isEditingExternally: .constant(false)
        )
    }
    .padding()
    .frame(width: 500)
}

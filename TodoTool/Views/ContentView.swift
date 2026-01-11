// ==================== 主界面视图 ====================
// 任务列表、添加任务、空状态展示
// 支持快捷键：⌘N 新建、⌘⌫ 删除、⌘F 搜索、⌘I 导入、Enter 编辑、⌘Enter 切换完成、Esc 取消
// 支持双击行内编辑、添加/删除/切换动画、实时搜索过滤

import SwiftUI
import AppKit

/// 视图模式枚举
enum ViewMode: String, CaseIterable {
    case list = "list"
    case quadrant = "quadrant"

    var displayName: String {
        switch self {
        case .list: return "列表视图"
        case .quadrant: return "四象限视图"
        }
    }

    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .quadrant: return "square.grid.2x2"
        }
    }

    /// 切换到另一个模式
    mutating func toggle() {
        self = self == .list ? .quadrant : .list
    }
}

struct ContentView: View {
    /// 状态管理器
    @StateObject private var todoStore = TodoStore()

    /// 当前显示的视图模式
    @State private var viewMode: ViewMode = .list

    /// 新任务输入状态
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskPriority: Priority = .none

    /// 搜索文本
    @State private var searchText = ""
    @State private var priorityFilter: PriorityFilter = .all
    @State private var tagFilter: UUID? = nil

    /// 选中的任务 ID 集合（支持多选）
    @State private var selectedTodoIds: Set<UUID> = []

    /// 正在编辑的任务 ID
    @State private var editingTodoId: UUID?

    /// 标签管理弹窗状态
    @State private var isManagingTags = false
    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .blue

    /// List 焦点状态
    @FocusState private var isListFocused: Bool

    /// 搜索框焦点状态
    @FocusState private var isSearchFocused: Bool

    /// 过滤后的任务列表
    private var filteredTodos: [Todo] {
        todoStore.filteredAndSortedTodos(searchText: searchText, priorityFilter: priorityFilter.priority, tagFilter: tagFilter)
    }



    /// 待办任务（未完成，已过滤）
    private var pendingTodos: [Todo] {
        filteredTodos.filter { !$0.isCompleted }
    }

    /// 已完成任务（已过滤）
    private var completedTodos: [Todo] {
        filteredTodos.filter { $0.isCompleted }
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || priorityFilter != .all || tagFilter != nil
    }

    // MARK: - 统计数据

    /// 待办任务总数
    private var totalPending: Int {
        todoStore.todos.filter { !$0.isCompleted }.count
    }

    /// 已完成任务总数
    private var totalCompleted: Int {
        todoStore.todos.filter { $0.isCompleted }.count
    }

    /// 今日完成数量
    private var completedToday: Int {
        todoStore.todos.filter { todo in
            guard todo.isCompleted, let completedAt = todo.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
    }

    var body: some View {
        Group {
            switch viewMode {
            case .list:
                listModeView
            case .quadrant:
                QuadrantView(
                    todoStore: todoStore,
                    onDismiss: { withAnimation { viewMode = .list } }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewMode)
        .frame(minWidth: 400, minHeight: 600)
        .sheet(isPresented: $isAddingTask) {
            addTaskSheet
        }
        .sheet(isPresented: $isManagingTags) {
            tagManagementSheet
        }
        // 监听菜单快捷键通知
        .onReceive(NotificationCenter.default.publisher(for: .addTask)) { _ in
            openAddTaskSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteTask)) { _ in
            deleteSelectedTodoAnimated()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTask)) { _ in
            toggleSelectedTodoAnimated()
        }
        .onReceive(NotificationCenter.default.publisher(for: .editTask)) { _ in
            startEditingSelectedTodo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            focusSearchBar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .setPriority)) { notification in
            if let priority = notification.userInfo?["priority"] as? Priority {
                setSelectedTodoPriorityAnimated(priority)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importDataRequest)) { notification in
            handleImportRequest(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoAction)) { _ in
            undoAnimated()
        }
        .onReceive(NotificationCenter.default.publisher(for: .redoAction)) { _ in
            redoAnimated()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearCompleted)) { _ in
            clearCompletedAnimated()
        }
        .onReceive(NotificationCenter.default.publisher(for: .manageTags)) { _ in
            isManagingTags = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleViewMode)) { _ in
            withAnimation { viewMode.toggle() }
        }
        // Enter 进入编辑模式（⌘+Enter 切换完成状态由菜单命令处理）
        .onKeyPress(.return) { handleEditShortcut() }
    }

    // MARK: - 列表模式主视图

    /// 列表模式视图
    private var listModeView: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            // 搜索框
            SearchFilterBar(
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                priorityFilter: $priorityFilter,
                tagFilter: $tagFilter,
                tags: todoStore.tags,
                clearSearch: clearSearch
            )

            Divider()

            // 主内容区 - 带过渡动画
            if todoStore.todos.isEmpty {
                emptyStateView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if filteredTodos.isEmpty {
                // 搜索无结果
                noResultsView
                    .transition(.opacity)
            } else {
                taskListView
                    .transition(.opacity)
            }

            // 底部统计面板
            if !todoStore.todos.isEmpty {
                Divider()
                statsBarView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: todoStore.todos.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: filteredTodos.count)
    }

    // MARK: - 子视图

    /// 底部统计面板
    private var statsBarView: some View {
        HStack(spacing: 16) {
            if selectedTodoIds.count > 1 {
                BatchActionsBar(
                    selectedCount: selectedTodoIds.count,
                    onToggle: toggleSelectedTodoAnimated,
                    onDelete: deleteSelectedTodoAnimated,
                    onCancel: { selectedTodoIds = [] }
                )
            } else {
                Label("\(totalPending)", systemImage: "circle")
                    .foregroundColor(.primary)
                    .help("待办任务")

                Label("\(totalCompleted)", systemImage: "checkmark.circle")
                    .foregroundColor(.green)
                    .help("已完成任务")

                Label("\(completedToday)", systemImage: "calendar")
                    .foregroundColor(.blue)
                    .help("今日完成")
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: undoAnimated) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(todoStore.canUndo ? .primary : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!todoStore.canUndo)
                .help("撤销 (⌘Z)")

                Button(action: redoAnimated) {
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundColor(todoStore.canRedo ? .primary : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!todoStore.canRedo)
                .help("重做 (⌘⇧Z)")
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .animation(.easeInOut(duration: 0.2), value: selectedTodoIds.count > 1)
    }

    /// 顶部标题栏
    private var headerView: some View {

        HStack {
            Text("待办事项")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // 视图模式切换按钮
            Button(action: { withAnimation { viewMode.toggle() } }) {
                Image(systemName: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help(viewMode == .list ? "切换到四象限视图 (⌘⇧Q)" : "切换到列表视图 (⌘⇧Q)")

            Button(action: openAddTaskSheet) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding()
    }



            

    /// 搜索无结果视图

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("未找到匹配的任务")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(hasActiveFilters ? "尝试调整搜索或优先级筛选" : "尝试其他搜索关键词")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))

            Button(action: clearFilters) {
                Text("清除条件")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// 任务列表
    private var taskListView: some View {
        List(selection: $selectedTodoIds) {
            // 待办分组
            if !pendingTodos.isEmpty {
                Section {
                    ForEach(pendingTodos) { todo in
                        todoRow(for: todo)
                    }
                    .onDelete { indexSet in
                        deleteTodosAnimated(from: pendingTodos, at: indexSet)
                    }
                    .onMove { source, destination in
                        moveTodosAnimated(from: source, to: destination, inSection: pendingTodos)
                    }
                } header: {
                    Text("待办 (\(pendingTodos.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 已完成分组
            if !completedTodos.isEmpty {
                Section {
                    ForEach(completedTodos) { todo in
                        todoRow(for: todo)
                    }
                    .onDelete { indexSet in
                        deleteTodosAnimated(from: completedTodos, at: indexSet)
                    }
                    .onMove { source, destination in
                        moveTodosAnimated(from: source, to: destination, inSection: completedTodos)
                    }
                } header: {
                    Text("已完成 (\(completedTodos.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
        .focusable()
        .focused($isListFocused)
        .animation(.easeInOut(duration: 0.25), value: todoStore.todos)
    }

    private func todoRow(for todo: Todo) -> some View {
        TodoRow(
            todo: todo,
            onToggle: { toggleTodoAnimated(id: todo.id) },
            onUpdate: { newTitle in
                updateTodoAnimated(id: todo.id, title: newTitle)
            },
            onDelete: {
                deleteTodoAnimated(id: todo.id)
            },
            onEditEnd: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    selectedTodoIds = [todo.id]
                    isListFocused = true
                }
            },
            onSetPriority: { priority in
                setTodoPriorityAnimated(id: todo.id, priority: priority)
            },
            onSetDueDate: { dueDate in
                setTodoDueDateAnimated(id: todo.id, dueDate: dueDate)
            },
            availableTags: todoStore.tags,
            onToggleTag: { tagId in
                toggleTagAnimated(todoId: todo.id, tagId: tagId)
            },
            isEditingExternally: editingBinding(for: todo.id)
        )
        .tag(todo.id)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("暂无任务")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("点击下方按钮或按 ⌘N 添加第一个待办事项")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))

            Button(action: openAddTaskSheet) {
                Label("添加任务", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// 添加任务弹窗
    private var addTaskSheet: some View {
        VStack(spacing: 16) {
            Text("新建任务")
                .font(.headline)

            TextField("任务标题", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 250)
                .onSubmit(addTaskAnimated)

            priorityPicker

            HStack(spacing: 12) {
                Button("取消") {
                    cancelAddTask()
                }
                .keyboardShortcut(.cancelAction)

                Button("添加") {
                    addTaskAnimated()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 300)
    }

    /// 标签管理弹窗
    private var tagManagementSheet: some View {
        VStack(spacing: 16) {
            Text("管理标签")
                .font(.headline)

            // 现有标签列表
            if todoStore.tags.isEmpty {
                Text("暂无标签")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(todoStore.tags) { tag in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(tag.color.color)
                                    .frame(width: 12, height: 12)

                                Text(tag.name)
                                    .foregroundColor(.primary)

                                Spacer()

                                // 删除按钮
                                Button {
                                    todoStore.deleteTag(id: tag.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Divider()

            // 添加新标签
            HStack(spacing: 12) {
                TextField("新标签名称", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 150)

                // 颜色选择
                Menu {
                    ForEach(TagColor.allCases, id: \.self) { color in
                        Button {
                            newTagColor = color
                        } label: {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                Text(color.displayName)
                                if newTagColor == color {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(newTagColor.color)
                        .frame(width: 16, height: 16)
                        .padding(4)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)

                Button("添加") {
                    guard !newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    todoStore.addTag(name: newTagName, color: newTagColor)
                    newTagName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button("完成") {
                isManagingTags = false
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(minWidth: 350, minHeight: 300)
    }

    // MARK: - 辅助方法

    /// 创建编辑状态 Binding
    private func editingBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { editingTodoId == id },
            set: { newValue in
                if newValue {
                    editingTodoId = id
                } else if editingTodoId == id {
                    editingTodoId = nil
                }
            }
        )
    }



    private func priorityTint(_ priority: Priority) -> Color {
        priority == .none ? .secondary : priority.color
    }

    // MARK: - 搜索操作

    /// 聚焦搜索框（⌘F 快捷键）
    private func focusSearchBar() {
        isSearchFocused = true
    }

    /// 清除搜索
    private func clearSearch() {
        searchText = ""
        isSearchFocused = false
    }

    /// 清除所有筛选条件
    private func clearFilters() {
        searchText = ""
        priorityFilter = .all
        tagFilter = nil
        isSearchFocused = false
    }

    // MARK: - 操作方法（带动画）

    /// 打开添加任务弹窗
    private func openAddTaskSheet() {
        isAddingTask = true
    }

    /// 添加任务（带动画）
    private func addTaskAnimated() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.add(title: title, priority: newTaskPriority)
        }
        cancelAddTask()
    }

    /// 取消添加
    private func cancelAddTask() {
        newTaskTitle = ""
        newTaskPriority = .none
        isAddingTask = false
    }

    // MARK: - 新建任务优先级选择

    private var priorityPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("优先级")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(Priority.orderedCases, id: \.self) { priority in
                    Button {
                        newTaskPriority = priority
                    } label: {
                        HStack(spacing: 4) {
                            if priority != .none {
                                Circle()
                                    .fill(priorityTint(priority))
                                    .frame(width: 6, height: 6)
                            }
                            Text(priority.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    newTaskPriority == priority
                                        ? priorityTint(priority).opacity(priority == .none ? 0.12 : 0.2)
                                        : Color.primary.opacity(0.05)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    newTaskPriority == priority
                                        ? priorityTint(priority).opacity(0.6)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 切换完成状态（带动画）
    private func toggleTodoAnimated(id: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.toggle(id: id)
        }
    }

    /// 更新标题（带动画）
    private func updateTodoAnimated(id: UUID, title: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            todoStore.update(id: id, title: title)
        }
    }

    /// 从指定列表删除任务（带动画）
    private func deleteTodosAnimated(from list: [Todo], at indexSet: IndexSet) {
        withAnimation(.easeInOut(duration: 0.25)) {
            for index in indexSet {
                let todo = list[index]
                todoStore.delete(id: todo.id)
            }
        }
    }

    /// 删除单个任务（带动画）
    private func deleteTodoAnimated(id: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.delete(id: id)
        }
        // 清除编辑状态
        if editingTodoId == id {
            editingTodoId = nil
        }
    }

    /// 删除选中的任务（⌘⌫ 快捷键，带动画）
    private func deleteSelectedTodoAnimated() {
        guard !selectedTodoIds.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.deleteMultiple(ids: selectedTodoIds)
        }
        selectedTodoIds = []
    }

    /// 切换选中任务的完成状态（带动画）
    private func toggleSelectedTodoAnimated() {
        guard !selectedTodoIds.isEmpty else { return }
        // 如果所有选中的都已完成，则标记为未完成；否则标记为已完成
        let allCompleted = selectedTodoIds.allSatisfy { id in
            todoStore.todos.first { $0.id == id }?.isCompleted ?? false
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.setCompleted(ids: selectedTodoIds, completed: !allCompleted)
        }
    }

    /// 开始编辑选中的任务（仅单选时有效）
    private func startEditingSelectedTodo() {
        guard selectedTodoIds.count == 1, let id = selectedTodoIds.first else { return }
        editingTodoId = id
    }

    /// 处理 Enter 快捷键 - 进入编辑模式（仅单选时有效）
    private func handleEditShortcut() -> KeyPress.Result {
        // 如果正在编辑，不拦截（让 TextField 处理）
        guard editingTodoId == nil else { return .ignored }
        guard selectedTodoIds.count == 1, let id = selectedTodoIds.first else { return .ignored }
        editingTodoId = id
        return .handled
    }

    /// 处理 ⌘+Enter 快捷键 - 切换完成状态
    private func handleToggleShortcut() -> KeyPress.Result {
        guard !selectedTodoIds.isEmpty else { return .ignored }
        toggleSelectedTodoAnimated()
        return .handled
    }

    /// 设置任务优先级（带动画）
    private func setTodoPriorityAnimated(id: UUID, priority: Priority) {
        withAnimation(.easeInOut(duration: 0.2)) {
            todoStore.setPriority(id: id, priority: priority)
        }
    }

    /// 设置选中任务的优先级（⌘0/1/2/3 快捷键，带动画）
    private func setSelectedTodoPriorityAnimated(_ priority: Priority) {
        guard !selectedTodoIds.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            todoStore.setPriorityMultiple(ids: selectedTodoIds, priority: priority)
        }
    }

    /// 设置任务到期日期（带动画）
    private func setTodoDueDateAnimated(id: UUID, dueDate: Date?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            todoStore.setDueDate(id: id, dueDate: dueDate)
        }
    }

    /// 切换任务标签（带动画）
    private func toggleTagAnimated(todoId: UUID, tagId: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let todo = todoStore.todos.first(where: { $0.id == todoId }),
               todo.tagIds.contains(tagId) {
                todoStore.removeTagFromTodo(todoId: todoId, tagId: tagId)
            } else {
                todoStore.addTagToTodo(todoId: todoId, tagId: tagId)
            }
        }
    }

    /// 移动任务到新位置（拖拽排序，带动画）
    private func moveTodosAnimated(from source: IndexSet, to destination: Int, inSection sectionTodos: [Todo]) {
        guard let sourceIndex = source.first,
              sourceIndex < sectionTodos.count else { return }
        let movedPriority = sectionTodos[sourceIndex].priority
        let adjustedDest = destination > sourceIndex ? destination - 1 : destination
        if adjustedDest >= 0, adjustedDest < sectionTodos.count {
            let targetPriority = sectionTodos[adjustedDest].priority
            guard targetPriority == movedPriority else { return }
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.move(from: source, to: destination, inSection: sectionTodos)
        }
    }

    // MARK: - 撤销/重做

    /// 撤销上一步操作（⌘Z 快捷键）
    private func undoAnimated() {
        guard todoStore.canUndo else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.undo()
        }
    }

    /// 重做已撤销的操作（⌘⇧Z 快捷键）
    private func redoAnimated() {
        guard todoStore.canRedo else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.redo()
        }
    }

    /// 清除所有已完成的任务（⌘⇧K 快捷键）
    private func clearCompletedAnimated() {
        guard totalCompleted > 0 else { return }
        let alert = NSAlert()
        alert.messageText = "确认清除已完成？"
        alert.informativeText = "此操作将删除所有已完成任务，可通过撤销恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.clearCompleted()
        }
        selectedTodoIds = selectedTodoIds.filter { id in
            todoStore.todos.contains { $0.id == id }
        }
    }

    // MARK: - 导入功能

    /// 处理导入请求通知
    private func handleImportRequest(_ notification: Notification) {
        guard let request = notification.object as? ImportRequest else { return }

        do {
            let result = try todoStore.importTodos(from: request.fileData, mode: request.mode)
            showImportResult(added: result.added, skipped: result.skipped, mode: request.mode)
        } catch {
            showImportError(error)
        }
    }

    /// 显示导入结果
    private func showImportResult(added: Int, skipped: Int, mode: ImportMode) {
        let alert = NSAlert()
        alert.messageText = "导入成功"

        switch mode {
        case .replace:
            alert.informativeText = "已覆盖导入 \(added) 个任务"
        case .merge:
            if skipped > 0 {
                alert.informativeText = "新增 \(added) 个任务，跳过 \(skipped) 个重复项"
            } else {
                alert.informativeText = "新增 \(added) 个任务"
            }
        }

        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    /// 显示导入错误
    private func showImportError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "导入失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

#Preview {
    ContentView()
}

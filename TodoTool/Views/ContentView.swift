// ==================== 主界面视图 ====================
// 任务列表、添加任务、空状态展示
// 支持快捷键：⌘N 新建、⌘⌫ 删除、⌘F 搜索、Enter 编辑、⌘Enter 切换完成、Esc 取消
// 支持双击行内编辑、添加/删除/切换动画、实时搜索过滤

import SwiftUI

struct ContentView: View {
    /// 状态管理器
    @StateObject private var todoStore = TodoStore()

    /// 新任务输入状态
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""

    /// 搜索文本
    @State private var searchText = ""

    /// 选中的任务 ID（用于快捷键操作）
    @State private var selectedTodoId: UUID?

    /// 正在编辑的任务 ID
    @State private var editingTodoId: UUID?

    /// List 焦点状态
    @FocusState private var isListFocused: Bool

    /// 搜索框焦点状态
    @FocusState private var isSearchFocused: Bool

    /// 过滤后的任务列表
    private var filteredTodos: [Todo] {
        if searchText.isEmpty {
            return todoStore.todos
        }
        return todoStore.todos.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 待办任务（未完成，已过滤）
    private var pendingTodos: [Todo] {
        filteredTodos.filter { !$0.isCompleted }
    }

    /// 已完成任务（已过滤）
    private var completedTodos: [Todo] {
        filteredTodos.filter { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            // 搜索框
            searchBarView

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
        }
        .animation(.easeInOut(duration: 0.3), value: todoStore.todos.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: filteredTodos.count)
        .frame(minWidth: 400, minHeight: 600)
        .sheet(isPresented: $isAddingTask) {
            addTaskSheet
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
        // Enter 进入编辑模式（⌘+Enter 切换完成状态由菜单命令处理）
        .onKeyPress(.return) { handleEditShortcut() }
    }

    // MARK: - 子视图

    /// 顶部标题栏
    private var headerView: some View {
        HStack {
            Text("待办事项")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: openAddTaskSheet) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding()
    }

    /// 搜索框
    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("搜索任务…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onExitCommand {
                    // Esc 清空搜索并取消焦点
                    searchText = ""
                    isSearchFocused = false
                    isListFocused = true
                }

            // 清除按钮
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
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

            Text("尝试其他搜索关键词")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))

            Button(action: clearSearch) {
                Text("清除搜索")
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
        List(selection: $selectedTodoId) {
            // 待办分组
            if !pendingTodos.isEmpty {
                Section {
                    ForEach(pendingTodos) { todo in
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
                                // 编辑结束后恢复 List 焦点和选中状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    selectedTodoId = todo.id
                                    isListFocused = true
                                }
                            },
                            onSelect: {
                                // 单击选中
                                selectedTodoId = todo.id
                            },
                            isEditingExternally: editingBinding(for: todo.id)
                        )
                        .tag(todo.id)
                    }
                    .onDelete { indexSet in
                        deleteTodosAnimated(from: pendingTodos, at: indexSet)
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
                                // 编辑结束后恢复 List 焦点和选中状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    selectedTodoId = todo.id
                                    isListFocused = true
                                }
                            },
                            onSelect: {
                                // 单击选中
                                selectedTodoId = todo.id
                            },
                            isEditingExternally: editingBinding(for: todo.id)
                        )
                        .tag(todo.id)
                    }
                    .onDelete { indexSet in
                        deleteTodosAnimated(from: completedTodos, at: indexSet)
                    }
                } header: {
                    Text("已完成 (\(completedTodos.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.inset)
        .focusable()
        .focused($isListFocused)
        .animation(.easeInOut(duration: 0.25), value: todoStore.todos)
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
            todoStore.add(title: title)
        }
        cancelAddTask()
    }

    /// 取消添加
    private func cancelAddTask() {
        newTaskTitle = ""
        isAddingTask = false
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
        guard let id = selectedTodoId else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.delete(id: id)
        }
        selectedTodoId = nil
    }

    /// 切换选中任务的完成状态（带动画）
    private func toggleSelectedTodoAnimated() {
        guard let id = selectedTodoId else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            todoStore.toggle(id: id)
        }
    }

    /// 开始编辑选中的任务
    private func startEditingSelectedTodo() {
        guard let id = selectedTodoId else { return }
        editingTodoId = id
    }

    /// 处理 Enter 快捷键 - 进入编辑模式
    private func handleEditShortcut() -> KeyPress.Result {
        // 如果正在编辑，不拦截（让 TextField 处理）
        guard editingTodoId == nil else { return .ignored }
        guard let id = selectedTodoId else { return .ignored }
        editingTodoId = id
        return .handled
    }

    /// 处理 ⌘+Enter 快捷键 - 切换完成状态
    private func handleToggleShortcut() -> KeyPress.Result {
        guard selectedTodoId != nil else { return .ignored }
        toggleSelectedTodoAnimated()
        return .handled
    }
}

#Preview {
    ContentView()
}

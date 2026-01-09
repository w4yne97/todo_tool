// ==================== 主界面视图 ====================
// 任务列表、添加任务、空状态展示

import SwiftUI

struct ContentView: View {
    /// 状态管理器
    @StateObject private var todoStore = TodoStore()
    
    /// 新任务输入状态
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    
    /// 待办任务（未完成）
    private var pendingTodos: [Todo] {
        todoStore.todos.filter { !$0.isCompleted }
    }
    
    /// 已完成任务
    private var completedTodos: [Todo] {
        todoStore.todos.filter { $0.isCompleted }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView
            
            Divider()
            
            // 主内容区
            if todoStore.todos.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .frame(minWidth: 400, minHeight: 600)
        .sheet(isPresented: $isAddingTask) {
            addTaskSheet
        }
    }
    
    // MARK: - 子视图
    
    /// 顶部标题栏
    private var headerView: some View {
        HStack {
            Text("待办事项")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: { isAddingTask = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding()
    }
    
    /// 任务列表
    private var taskListView: some View {
        List {
            // 待办分组
            if !pendingTodos.isEmpty {
                Section {
                    ForEach(pendingTodos) { todo in
                        TodoRow(todo: todo) {
                            todoStore.toggle(id: todo.id)
                        }
                    }
                    .onDelete { indexSet in
                        deleteTodos(from: pendingTodos, at: indexSet)
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
                        TodoRow(todo: todo) {
                            todoStore.toggle(id: todo.id)
                        }
                    }
                    .onDelete { indexSet in
                        deleteTodos(from: completedTodos, at: indexSet)
                    }
                } header: {
                    Text("已完成 (\(completedTodos.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.inset)
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
            
            Text("点击下方按钮添加第一个待办事项")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
            
            Button(action: { isAddingTask = true }) {
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
                .onSubmit(addTask)
            
            HStack(spacing: 12) {
                Button("取消") {
                    cancelAddTask()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("添加") {
                    addTask()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 300)
    }
    
    // MARK: - 操作方法
    
    /// 添加任务
    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        todoStore.add(title: title)
        cancelAddTask()
    }
    
    /// 取消添加
    private func cancelAddTask() {
        newTaskTitle = ""
        isAddingTask = false
    }
    
    /// 从指定列表删除任务
    private func deleteTodos(from list: [Todo], at indexSet: IndexSet) {
        for index in indexSet {
            let todo = list[index]
            todoStore.delete(id: todo.id)
        }
    }
}

#Preview {
    ContentView()
}

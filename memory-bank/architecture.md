# TodoTool 架构文档

---

## 整体架构

```
┌─────────────────────────────────────────────────┐
│                  Views 层                        │
│  负责 UI 渲染，不包含业务逻辑                    │
│  ContentView.swift / TodoRow.swift              │
└──────────────────────┬──────────────────────────┘
                       │ @StateObject 绑定
                       ▼
┌─────────────────────────────────────────────────┐
│                   Store 层                       │
│  状态管理 + 持久化 + 业务逻辑                    │
│  TodoStore.swift                                │
└──────────────────────┬──────────────────────────┘
                       │ Codable 序列化
                       ▼
┌─────────────────────────────────────────────────┐
│                  Models 层                       │
│  纯数据结构，无副作用                            │
│  Todo.swift / TodoData.swift                    │
└──────────────────────┬──────────────────────────┘
                       │ JSON 文件
                       ▼
┌─────────────────────────────────────────────────┐
│               File System                        │
│  ~/Library/Application Support/TodoTool/        │
└─────────────────────────────────────────────────┘
```

---

## 文件职责说明

### 项目配置

| 文件 | 职责 | 关键点 |
|------|------|--------|
| `TodoTool.xcodeproj/project.pbxproj` | Xcode 项目配置 | 定义构建目标、编译设置、文件引用 |
| `TodoTool/TodoTool.entitlements` | App Sandbox 权限 | 启用沙盒，系统管理容器路径 |

### 应用入口

| 文件 | 职责 | 关键点 |
|------|------|--------|
| `TodoTool/TodoToolApp.swift` | 应用启动入口 + 菜单命令 | `@main` 标记，`WindowGroup` 管理窗口场景，`.commands` 注册快捷键 |
| `TodoTool/Notifications.swift` | 跨层通信通知定义 | 定义 App 与 View 层通信的 `Notification.Name` 常量 |

### Models 层（数据模型）

| 文件 | 职责 | 关键点 |
|------|------|--------|
| `Todo.swift` | 单个任务的数据结构 | 遵循 `Codable`、`Identifiable`、`Equatable`；提供自定义 ISO8601 编解码器 |
| `TodoData.swift` | JSON 存储容器 | 包含 `version`（用于未来迁移）和 `todos` 数组；提供 `empty` 静态属性 |

**设计原则**：
- 纯值类型（struct），无副作用
- 所有属性使用基本类型或标准库类型
- 日期使用 ISO8601 UTC 格式，兼容带/不带毫秒

**Todo.swift 核心实现**：
- `id: UUID` - 唯一标识（let，不可变）
- `title: String` - 任务标题（var，可编辑）
- `isCompleted: Bool` - 完成状态
- `createdAt: Date` - 创建时间（let，不可变）
- `completedAt: Date?` - 完成时间（nil 表示未完成）
- `updatedAt: Date` - 最近修改时间
- `Todo.encoder` / `Todo.decoder` - 自定义 JSON 编解码器

**TodoData.swift 核心实现**：
- `version: Int` - 数据格式版本号（当前为 1）
- `todos: [Todo]` - 任务数组
- `TodoData.empty` - 空数据默认值
- `encoded() -> Data` - 编码为 JSON
- `decoded(from:) -> TodoData` - 从 JSON 解码

### Store 层（状态管理 + 持久化 + 业务逻辑）

| 文件 | 职责 | 关键点 |
|------|------|--------|
| `TodoStore.swift` | 状态管理 + 持久化 + CRUD 业务逻辑 | `ObservableObject`，`@Published todos`，原子写入 |

**核心属性**：
- `todos: [Todo]` - `@Published`，任务数组，UI 自动响应变化
- `tags: [Tag]` - 标签列表
- 过滤缓存：`cachedFilteredTodos`、`lastFilterParams`、`cacheDirty`
- `dataURL` / `backupURL` / `tempURL` - 数据文件路径

**核心方法**：
- `load()` - 主文件→备份→空数据，损坏记录日志，回退后保存
- `save()` / `saveSafely()` - 原子写入（tmp → backup → rename）并失效缓存
- `filteredAndSortedTodos` - 参数+数据缓存，失效由 `markDirty` 驱动
- `add`/`toggle`/`delete`/`update`/`setPriority`/`setDueDate` - 所有写操作持久化并写入历史
- `move` - 同优先级拖拽校验，必要时归一化 `sortOrder`
- `importTodos` - 覆盖/合并导入，返回新增/跳过计数
- 标签 CRUD/关联操作全部写入历史，可撤销

**设计原则**：
- 单一数据源（Single Source of Truth）
- 所有状态变更通过明确方法触发
- 写入失败时保证数据不丢失（原子写入 + 备份恢复）
- 支持依赖注入（`dataDirectory` 参数），便于单元测试
- **防御性编程**：所有 CRUD 方法对无效输入静默处理，不抛异常

**原子写入流程**：
```
1. 编码数据 → data.json.tmp
2. 若主文件存在 → 重命名 data.json → data.json.backup
3. 重命名 data.json.tmp → data.json
4. 任何步骤失败 → load() 时从 backup 恢复
```

**边界条件处理**：
| 场景 | 行为 |
|------|------|
| 空标题或纯空格标题 | 静默拒绝添加/更新 |
| 标题超过 200 字符 | 静默拒绝添加/更新 |
| 操作不存在的 ID | 静默忽略，不影响现有数据 |

### Views 层（视图）

| 文件 | 职责 | 关键点 |
|------|------|--------|
| `ContentView.swift` | 主界面容器 | `@StateObject` 持有 TodoStore，分组列表，快捷键处理，空状态展示，已完成分组折叠 |
| `TodoRow.swift` | 单行任务视图 | 接收 Todo + 回调，完成状态图标，删除线样式，完成时间 |

**ContentView.swift 核心实现**：
- `@StateObject todoStore` - 持有 TodoStore 单例
- `@State selectedTodoId` - 追踪选中任务（用于快捷键操作）
- `pendingTodos` / `completedTodos` - 计算属性，按完成状态分组
- `headerView` - 标题栏 + 新增按钮
- `taskListView` - List + Section 分组显示，支持 selection
- `emptyStateView` - 无任务时的引导界面
- `addTaskSheet` - Sheet 弹窗输入新任务
- 滑动删除（`.onDelete` 修饰符）
- 快捷键监听（`.onReceive` + `.onKeyPress`）

**TodoRow.swift 核心实现**：
- `todo: Todo` - 任务数据
- `onToggle: () -> Void` - 切换完成状态回调
- 左侧完成图标（空心圆 / 勾选圆）
- 中间任务标题（已完成时添加删除线 + 灰色）
- 右侧完成时间（今天只显示时间，其他显示完整日期）
- `contentShape(Rectangle())` - 确保整行可点击

**设计原则**：
- View 只负责渲染，不包含业务逻辑
- 通过回调（closure）与 Store 通信
- 使用 SwiftUI 声明式语法
- 乐观更新，状态变更立即反映到 UI

### 测试目录

| 文件 | 职责 | 关键点 |
|------|------|--------|
| `TodoToolTests/TodoModelTests.swift` | 数据模型单元测试 | 12 个测试用例覆盖创建、编解码、日期格式兼容性 |
| `TodoToolTests/TodoStoreTests.swift` | 持久化+业务逻辑单元测试 | 21 个测试用例覆盖加载、保存、CRUD、异常恢复、边界条件 |

---

## 数据流

```
用户操作 → View → Store.method() → 更新 @Published → View 刷新
                       ↓
                   save() → JSON 文件
```

**单向数据流**：
1. 用户在 View 层触发操作（点击、滑动）
2. View 调用 Store 的方法
3. Store 更新内部状态（`@Published`）
4. SwiftUI 自动刷新绑定的 View
5. Store 同步持久化到 JSON 文件

---

## 文件存储

**位置**：`~/Library/Application Support/TodoTool/`（Sandbox 模式下为容器路径）

```
data.json          # 主数据文件
data.json.backup   # 上次成功写入的备份
data.json.tmp      # 写入中的临时文件（成功后删除）
```

**加载优先级**：
```
1. 尝试读取 data.json
2. 若失败 → 尝试读取 data.json.backup
3. 若仍失败 → 使用空数据 []
```

---

## 依赖关系

```
TodoToolApp
    └── ContentView
            ├── TodoRow (foreach)
            └── TodoStore (StateObject)
                    ├── Todo (Model)
                    └── TodoData (Model)

TodoToolTests
    ├── TodoModelTests
    │       ├── Todo
    │       └── TodoData
    └── TodoStoreTests
            └── TodoStore
                    ├── Todo
                    └── TodoData
```

**零外部依赖**：仅使用系统框架
- SwiftUI（UI 框架）
- Foundation（基础库，包含 FileManager、JSONEncoder 等）
- XCTest（测试框架）

---

## 目录结构

```
TodoTool/
├── TodoToolApp.swift           # 应用入口 + 菜单命令
├── Notifications.swift         # 跨层通信通知定义
├── TodoTool.entitlements       # App Sandbox 配置
├── Models/
│   ├── Todo.swift              # 单个任务数据模型
│   └── TodoData.swift          # JSON 存储容器
├── Store/
│   └── TodoStore.swift         # 状态管理 + 持久化 + 业务逻辑
└── Views/
    ├── ContentView.swift       # 主界面 + 快捷键处理
    └── TodoRow.swift           # 单行任务视图

TodoToolTests/
├── TodoModelTests.swift        # 数据模型测试（12 用例）
└── TodoStoreTests.swift        # 持久化+业务逻辑测试（21 用例）
```

---

## 架构洞察

### 为什么选择三层极简架构？

```
View → Store → File
```

**传统 MVVM 架构**需要 ViewModel 层作为 View 和 Model 之间的桥梁。但对于 TodoTool 这样的极简应用：

1. **数据结构简单**：只有一个 `Todo` 模型，无复杂关联
2. **业务逻辑轻量**：CRUD 操作可内聚在 Store 中
3. **状态管理直接**：`@Published` + `@StateObject` 已足够

因此，**Store 层同时承担 ViewModel 和 Repository 的职责**，省去不必要的抽象层。

---

### 原子写入的必要性

```
tmp → backup → rename
```

为什么不能直接覆盖 `data.json`？

| 直接写入风险 | 原子写入保护 |
|-------------|-------------|
| 写入中断导致数据丢失 | 临时文件写入失败不影响主文件 |
| 磁盘满导致文件截断 | 主文件始终完整 |
| 应用崩溃导致半写状态 | 重启后从 backup 恢复 |

**核心原则**：任何时刻，`data.json` 或 `data.json.backup` 至少有一个是完整可用的。

---

### 防御性设计：静默失败 vs 抛出异常

TodoStore 的 CRUD 方法选择**静默失败**而非抛出异常：

```swift
// 空标题 → 静默忽略，不添加
func add(title: String) {
    guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    // ...
}
```

**理由**：
1. 用户操作不应导致应用崩溃
2. UI 层已有验证（按钮禁用、输入提示）
3. 数据完整性由 Store 层兜底保证

---

### Sandbox 模式下的数据路径

```
非 Sandbox：~/Library/Application Support/TodoTool/
Sandbox：   ~/Library/Containers/com.yourname.TodoTool/Data/Library/Application Support/TodoTool/
```

代码中使用 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` 自动适配两种模式，无需硬编码路径。

---

### 测试策略：依赖注入

```swift
init(dataDirectory: URL? = nil)
```

TodoStore 支持注入自定义数据目录，使单元测试可以：
1. 使用临时目录，避免污染用户数据
2. 测试后清理，保持测试隔离
3. 模拟各种文件系统状态（空目录、损坏文件等）

---

### 文件职责一句话总结

| 文件 | 一句话职责 |
|------|----------|
| `TodoToolApp.swift` | 应用启动入口，配置窗口和菜单命令 |
| `Notifications.swift` | 定义 App 与 View 层通信的通知名称常量 |
| `Todo.swift` | 单个任务的数据结构，支持 JSON 序列化 |
| `TodoData.swift` | JSON 文件的顶层容器，包含版本号和任务数组 |
| `TodoStore.swift` | 单一数据源，管理状态、持久化和业务逻辑 |
| `ContentView.swift` | 主界面，分组显示任务列表，处理快捷键 |
| `TodoRow.swift` | 单行任务视图，展示完成状态和标题 |
| `TodoModelTests.swift` | 验证数据模型的序列化和边界条件 |
| `TodoStoreTests.swift` | 验证持久化、异常恢复和 CRUD 操作 |

---

### 快捷键架构：App 与 View 的解耦通信

```
┌─────────────────────┐     NotificationCenter      ┌─────────────────────┐
│   TodoToolApp       │ ──────────────────────────▶ │   ContentView       │
│   (菜单命令)         │      .addTask               │   (快捷键处理)       │
│   ⌘N / ⌘⌫ / Enter   │      .deleteTask            │   .onReceive()      │
└─────────────────────┘      .toggleTask            └─────────────────────┘
```

**为什么选择 NotificationCenter 而非 FocusedValue？**

| 方案 | 优点 | 缺点 |
|------|------|------|
| **NotificationCenter** | 简单直接、无需额外状态、编译顺序无关 | 松耦合、类型不安全 |
| **FocusedValue** | 类型安全、SwiftUI 原生 | 需要 FocusedValueKey、编译顺序敏感 |

对于 TodoTool 这样的简单应用，NotificationCenter 的简洁性优势明显：
1. **单向通信**：菜单 → View，无需双向绑定
2. **无状态依赖**：不需要 View 暴露内部状态给 App
3. **易于扩展**：新增快捷键只需添加通知名称和监听

---

### 快捷键实现策略

| 快捷键类型 | 实现方式 | 适用场景 |
|-----------|----------|----------|
| 菜单快捷键 | `.commands` + `CommandGroup` | ⌘N、⌘⌫ 等需要出现在菜单栏的快捷键 |
| 非菜单快捷键 | `.onKeyPress()` | Enter、Space 等不需要菜单项的快捷键 |
| 对话框快捷键 | `.keyboardShortcut(.cancelAction/.defaultAction)` | Esc 取消、Enter 确认 |

**关键点**：
- `List(selection:)` 追踪选中项，为删除/切换提供目标
- `.tag(todo.id)` 必须设置，否则 selection 不生效
- `.onKeyPress` 返回 `.handled` 阻止事件继续传播

---

*文档版本: v2.0 | 更新时间: 2026-01-09*

---

### 行内编辑架构

```
┌─────────────────────────────────────────────────────────────┐
│                        TodoRow                               │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │ @State isEditing │───▶│ 显示模式: Text (双击触发编辑)    │ │
│  │ @State editTitle │    │ 编辑模式: TextField (Enter/Esc) │ │
│  │ @FocusState      │    └─────────────────────────────────┘ │
│  └─────────────────┘                                         │
│              │                                               │
│              │ onUpdate?(newTitle)                           │
│              ▼                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              ContentView.updateTodoAnimated()            │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**关键点**：
- 编辑状态局部于 `TodoRow`，不影响全局状态
- `@FocusState` 控制 TextField 焦点，延迟聚焦确保渲染完成
- `onExitCommand` 处理 Esc 键取消编辑

---

### 动画策略

| 层级 | 实现方式 | 作用 |
|------|----------|------|
| 操作级 | `withAnimation { store.method() }` | 包装单个操作的状态变更 |
| 列表级 | `.animation(_, value: todos)` | List 整体监听 todos 变化 |

**为什么两层都需要？**

1. **操作级动画**：确保用户触发的操作有即时视觉反馈
2. **列表级动画**：处理 List 结构变化（Section 增删、行移动）

---

### 导出功能架构

```
TodoToolApp.exportData()
        │
        ├── 1. 读取 ~/Library/Application Support/TodoTool/data.json
        │
        ├── 2. 格式化 JSON (prettyPrinted + sortedKeys)
        │
        ├── 3. NSSavePanel 选择保存位置
        │       └── 默认文件名: TodoTool_Export_yyyyMMdd_HHmmss.json
        │
        └── 4. 写入文件 + 显示结果提示 (NSAlert)
```

**设计决策**：
- 直接读取数据文件而非通过 TodoStore，避免 App 与 View 共享状态
- 使用 `NSSavePanel` 而非 `fileExporter`，后者在 SwiftUI 中对 JSON 支持有限
- 导出格式与存储格式一致，便于作为备份恢复

---

### 完整文件职责表（Phase 7.2 更新）

| 文件 | 职责 | 最近新增功能 |
|------|------|------------------|
| `TodoToolApp.swift` | 应用入口、窗口配置、菜单命令、外观设置 | ⌘F 搜索快捷键 (Phase 7.2) |
| `Notifications.swift` | App 与 View 的通知名称常量 | `.focusSearch` (Phase 7.2) |
| `Todo.swift` | 任务数据模型、JSON 序列化 | — |
| `TodoData.swift` | JSON 顶层容器、版本管理 | — |
| `TodoStore.swift` | 状态管理、持久化、CRUD 逻辑 | — |
| `ContentView.swift` | 主界面、列表、快捷键、搜索过滤 | 搜索框、过滤逻辑 (Phase 7.2) |
| `TodoRow.swift` | 单行视图、完成状态、标题显示 | 行内编辑 |

---

*文档版本: v3.0 | 更新时间: 2026-01-09*

---

### 手势处理策略

```swift
// TodoRow 手势组合
.gesture(TapGesture(count: 2).onEnded { startEditing() })  // 双击编辑
.simultaneousGesture(TapGesture(count: 1).onEnded { onSelect?() })  // 单击选中
```

**为什么需要 simultaneousGesture？**

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 单击不触发 List 选中 | `onTapGesture` 阻止事件传递 | `simultaneousGesture` 允许手势并行 |
| 双击误触单击 | SwiftUI 自动处理 count 区分 | 无需额外处理 |

---

### 焦点管理架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        ContentView                               │
│  @FocusState isListFocused: Bool ◄─────────────────────────────┐ │
│  @State editingTodoId: UUID? ◄──── onEditEnd 触发重置          │ │
│  @State selectedTodoId: UUID? ◄─── onSelect 触发设置           │ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          TodoRow                                 │
│  @Binding isEditingExternally ◄─── editingBinding(for: id)     │
│  @FocusState isFocused ──────────► TextField 焦点              │
│                                                                  │
│  onChange(of: isFocused) ─────────► 焦点丢失时 confirmEdit()   │
└─────────────────────────────────────────────────────────────────┘
```

---

### 动画配置参考

| 动画类型 | 配置 | 适用场景 |
|---------|------|----------|
| 弹性动画 | `spring(response: 0.3, dampingFraction: 0.6)` | 图标状态变化 |
| 标准过渡 | `easeInOut(duration: 0.25)` | 列表增删 |
| 快速过渡 | `easeInOut(duration: 0.15)` | 标题更新 |
| 状态切换 | `easeInOut(duration: 0.2)` | 编辑模式 |
| 空状态切换 | `easeInOut(duration: 0.3)` | 空/有数据 |

---

*文档版本: v4.0 | 更新时间: 2026-01-10*

---

## Phase 7 架构预览

### 数据模型扩展

```
TodoData (v2)
├── version: Int
├── todos: [Todo]
│   ├── id, title, isCompleted, ...
│   ├── priority: Priority      (新增)
│   ├── dueDate: Date?          (新增)
│   ├── sortOrder: Int          (新增)
│   └── tagIds: [UUID]          (新增)
└── tags: [Tag]                 (新增)
    ├── id: UUID
    ├── name: String
    └── color: String
```

### 撤销/重做架构

```
┌─────────────────────────────────────────┐
│              TodoStore                   │
│  @Published todos: [Todo]               │
│                                         │
│  history: [[Todo]]    ◄── 状态快照栈    │
│  historyIndex: Int    ◄── 当前位置      │
│                                         │
│  saveState()          ◄── 操作后保存    │
│  undo() / redo()      ◄── ⌘Z / ⌘⇧Z     │
└─────────────────────────────────────────┘
```

### 版本迁移策略

```
加载时：
1. 读取 version
2. 如果 version < CurrentVersion
   → 执行迁移逻辑
   → 填充新字段默认值
   → 更新 version
3. 继续加载
```

---

*文档版本: v5.0 | 更新时间: 2026-01-10*

---

## Phase 7.1: 深色模式架构

### 外观模式管理

```
┌─────────────────────────────────────────────────────────────────┐
│                        TodoToolApp                               │
│                                                                  │
│  @AppStorage("appearanceMode")  ◄─── UserDefaults 持久化        │
│         │                                                        │
│         ▼                                                        │
│  AppearanceMode (enum)                                          │
│  ├── .system  → colorScheme: nil     → 跟随系统                 │
│  ├── .light   → colorScheme: .light  → 强制浅色                 │
│  └── .dark    → colorScheme: .dark   → 强制深色                 │
│         │                                                        │
│         ▼                                                        │
│  ContentView()                                                   │
│      .preferredColorScheme(currentMode.colorScheme)             │
└─────────────────────────────────────────────────────────────────┘
```

### 为什么使用 `@AppStorage` 而非自定义持久化？

| 方案 | 优点 | 缺点 |
|------|------|------|
| **@AppStorage** | 零配置、自动同步、类型安全 | 仅支持基本类型 |
| 自定义 UserDefaults | 完全控制 | 需要手动读写、同步 |
| 写入 data.json | 与任务数据统一 | 增加 TodoStore 复杂度 |

**结论**：外观偏好是应用级设置，与任务数据无关，使用 `@AppStorage` 最简洁。

### 语义化颜色的深色模式适配

```swift
// 这些颜色会自动适配深色模式：
.primary      // 浅色: 黑色 → 深色: 白色
.secondary    // 浅色: 灰色 → 深色: 浅灰色
.accentColor  // 跟随系统强调色
.green        // 系统绿色（深色模式下亮度调整）

// 不要使用硬编码颜色：
Color(red: 0, green: 0, blue: 0)  // ❌ 不会适配深色模式
Color.black                        // ❌ 永远是黑色
```

**设计原则**：优先使用语义化颜色，让系统处理深色模式适配。

### 菜单结构

```
菜单栏
├── 文件
│   ├── 新建任务 (⌘N)
│   └── 导出数据… (⌘E)
├── 编辑
│   ├── 搜索任务 (⌘F)      ◄── Phase 7.2 新增
│   ├── 删除任务 (⌘⌫)
│   └── 切换完成状态 (⌘↵)
└── 视图
    └── 外观
        ├── ✓ 跟随系统
        ├── 浅色
        └── 深色
```

---

*文档版本: v6.0 | 更新时间: 2026-01-10*

---

## Phase 7.2: 搜索过滤架构

### 搜索数据流

```
┌─────────────────────────────────────────────────────────────────┐
│                        ContentView                               │
│                                                                  │
│  @State searchText: String                                      │
│         │                                                        │
│         ▼                                                        │
│  filteredTodos: [Todo] (计算属性)                               │
│  ├── searchText.isEmpty ? todos : todos.filter { ... }          │
│  │                                                               │
│  ▼                                                               │
│  pendingTodos / completedTodos                                  │
│  └── 基于 filteredTodos 再次过滤                                │
│         │                                                        │
│         ▼                                                        │
│  taskListView / noResultsView                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 为什么在 View 层过滤而非 Store 层？

| 方案 | 优点 | 缺点 |
|------|------|------|
| **View 层过滤** | 不修改原始数据、搜索状态与 UI 绑定更自然 | 每次重算 |
| Store 层过滤 | 可以缓存结果 | 增加 Store 复杂度、状态管理更复杂 |

**结论**：搜索是纯展示逻辑，不应影响持久化数据。计算属性在 SwiftUI 中非常高效，无需额外优化。

### 搜索框 UI 结构

```
┌─────────────────────────────────────────────────────────────────┐
│  🔍  │  搜索任务…                              │  ✕ (清除按钮)  │
└─────────────────────────────────────────────────────────────────┘
     │                                                │
     │  TextField                                     │  仅在有文本时显示
     │  .focused($isSearchFocused)                   │  .transition(.opacity)
     │  .onExitCommand { clearSearch() }            │
```

### 三种状态切换

```
todoStore.todos.isEmpty?
├── true  → emptyStateView (空状态引导)
└── false → filteredTodos.isEmpty?
            ├── true  → noResultsView (搜索无结果)
            └── false → taskListView (任务列表)
```

### 快捷键实现

```swift
// TodoToolApp.swift - 菜单注册
Button("搜索任务") {
    NotificationCenter.default.post(name: .focusSearch, object: nil)
}
.keyboardShortcut("f", modifiers: .command)

// ContentView.swift - 响应处理
.onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
    isSearchFocused = true  // @FocusState 赋值即可聚焦
}
```

---

## Phase 7.4: 导入功能架构

### 导入数据流

```
┌─────────────────────────────────────────────────────────────────┐
│                        TodoToolApp                               │
│                                                                  │
│  importData()                                                   │
│  ├── 1. NSOpenPanel 选择文件                                    │
│  ├── 2. 读取并验证 JSON                                         │
│  ├── 3. showImportOptionsDialog() 选择模式                      │
│  └── 4. NotificationCenter.post(.importDataRequest)             │
│              │                                                   │
│              ▼ ImportRequest(fileData, mode)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                      ContentView                           │  │
│  │  handleImportRequest()                                     │  │
│  │  └── todoStore.importTodos(from: data, mode: mode)        │  │
│  │              │                                             │  │
│  │              ▼                                             │  │
│  │  showImportResult() / showImportError()                   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 为什么 App 层不直接操作 TodoStore？

| 方案 | 优点 | 缺点 |
|------|------|------|
| **App 层操作文件** | 简单直接 | 绕过 Store，数据不一致风险 |
| **共享 TodoStore 实例** | 统一数据源 | App 和 View 紧耦合 |
| **NotificationCenter 传递** | 解耦、View 控制 Store | 需要额外通知定义 |

**选择 NotificationCenter 方案的原因**：
1. 保持 View 层对 TodoStore 的独占控制
2. App 层只负责 UI 交互，不涉及数据操作
3. 与现有快捷键架构一致（都用 NotificationCenter）

### 导入模式设计

```swift
enum ImportMode {
    case replace  // 覆盖：todos = newTodos
    case merge    // 合并：todos.insert(contentsOf: unique, at: 0)
}
```

**合并模式的 ID 去重**：
```swift
let existingIds = Set(todos.map { $0.id })  // O(n) 构建
let unique = newTodos.filter { !existingIds.contains($0.id) }  // O(m) 过滤
// 总复杂度 O(n+m)，适合大数据量
```

### App Sandbox 文件访问权限

```xml
<!-- TodoTool.entitlements -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

| 权限 | 说明 |
|------|------|
| `app-sandbox` | 启用沙盒，限制文件系统访问 |
| `files.user-selected.read-write` | 允许通过 NSOpenPanel/NSSavePanel 访问用户选择的文件 |

**为什么需要这个权限？**
- App Sandbox 默认只能访问自己的容器目录
- 导入/导出需要访问用户选择的任意位置
- 此权限是「用户授权」模式，只有用户主动选择的文件才可访问

### 完整文件职责表（Phase 7.4 更新）

| 文件 | 职责 | Phase 7.4 新增 |
|------|------|----------------|
| `TodoTool.entitlements` | App Sandbox 权限配置 | `user-selected.read-write` |
| `TodoToolApp.swift` | 应用入口、窗口配置、菜单命令 | 导入菜单项 (⌘I)、`importData()`、`showImportOptionsDialog()` |
| `Notifications.swift` | App 与 View 的通知名称常量 | `ImportMode` 枚举、`ImportRequest` 结构、`.importDataRequest` |
| `TodoStore.swift` | 状态管理、持久化、CRUD 逻辑 | `importTodos(from:mode:)` |
| `ContentView.swift` | 主界面、列表、快捷键 | `handleImportRequest()`、`showImportResult()`、`showImportError()` |

---

*文档版本: v8.0 | 更新时间: 2026-01-10*

---

## Phase 7.5-7.10: 高级功能架构

### 撤销/重做架构 (7.5)

```
┌─────────────────────────────────────────────────────────────────┐
│                          TodoStore                               │
│                                                                  │
│  @Published todos: [Todo]                                       │
│                                                                  │
│  history: [HistoryState]   ◄── 状态快照栈（todos+tags，最大 50 个）│
│  historyIndex: Int         ◄── 当前位置（-1 到 history.count-1）│
│                                                                  │
│  saveState()               ◄── 每次 CRUD/标签操作后调用         │
│  ├── 截断 historyIndex 之后的历史（新分支）                     │
│  ├── 追加当前 todos+tags 快照                                   │
│  └── 超过 maxHistorySize 时移除最旧记录                         │
│                                                                  │
│  undo()                    ◄── historyIndex--，恢复上一状态（含标签）│
│  redo()                    ◄── historyIndex++，恢复下一状态（含标签）│
│                                                                  │
│  canUndo: Bool             ◄── historyIndex > 0                 │
│  canRedo: Bool             ◄── historyIndex < history.count - 1 │
└─────────────────────────────────────────────────────────────────┘
```

**设计决策**：
- **快照式历史**：每次操作保存完整 todos 数组，而非 diff
- **优点**：实现简单，恢复可靠
- **缺点**：内存占用较大（50 个快照上限控制）

### 批量操作架构 (7.9)

```
┌─────────────────────────────────────────────────────────────────┐
│                        ContentView                               │
│                                                                  │
│  @State selectedTodoIds: Set<UUID>  ◄── 多选状态                │
│                                                                  │
│  List(selection: $selectedTodoIds)  ◄── 原生多选支持            │
│      .tag(todo.id)                  ◄── 每行必须设置 tag        │
│                                                                  │
│  batchActionsView                   ◄── 选中 > 1 时显示批量操作 │
│  ├── 批量删除                                                   │
│  ├── 批量完成/取消完成                                          │
│  └── 批量设置优先级                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          TodoStore                               │
│                                                                  │
│  deleteMultiple(ids: Set<UUID>)                                 │
│  setCompleted(ids: Set<UUID>, completed: Bool)                  │
│  setPriorityMultiple(ids: Set<UUID>, priority: Priority)        │
│  clearCompleted()                                                │
└─────────────────────────────────────────────────────────────────┘
```

**为什么使用 `Set<UUID>` 而非 `[UUID]`？**
- **O(1) 查找**：判断是否包含某 ID 更高效
- **去重保证**：自动去除重复选择
- **与 List selection 兼容**：macOS 原生多选返回 Set

### 标签系统架构 (7.10)

```
┌─────────────────────────────────────────────────────────────────┐
│                        TodoData (v2)                             │
│                                                                  │
│  version: Int = 1                                               │
│  todos: [Todo]                                                   │
│      └── tagIds: [UUID]  ◄── 多对多关系（引用）                 │
│  tags: [Tag]             ◄── 独立标签存储                       │
│      ├── id: UUID                                               │
│      ├── name: String                                           │
│      └── color: TagColor                                        │
└─────────────────────────────────────────────────────────────────┘
```

**规范化设计的优势**：

| 方案 | 优点 | 缺点 |
|------|------|------|
| **规范化**（当前） | 无冗余、易修改标签名/颜色 | 需要 join 查询 |
| 嵌入式 | 读取快 | 修改标签需遍历所有任务 |

**TagColor 枚举**：
```swift
enum TagColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray

    var color: Color { ... }      // SwiftUI 颜色
    var displayName: String { ... } // 中文名称
}
```

### 向后兼容策略

```swift
// Todo.swift - 新字段使用默认值
init(from decoder: Decoder) throws {
    // 旧字段...
    tagIds = try container.decodeIfPresent([UUID].self, forKey: .tagIds) ?? []
}

// TodoData.swift - 新数组使用空默认
init(from decoder: Decoder) throws {
    // ...
    tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
}
```

**原则**：新字段必须有合理默认值，旧数据无损加载。

### 完整文件职责表（Phase 7.10 更新）

| 文件 | 职责 | Phase 7.5-7.10 新增 |
|------|------|---------------------|
| `TodoToolApp.swift` | 应用入口、菜单命令 | ⌘Z/⌘⇧Z 撤销重做、⌘⇧K 清除已完成、⌘⇧T 管理标签 |
| `Notifications.swift` | 通知名称常量 | `.undoAction` `.redoAction` `.clearCompleted` `.manageTags` |
| `Todo.swift` | 任务数据模型 | `dueDate` `sortOrder` `tagIds` `isOverdue` `isDueSoon` |
| `TodoData.swift` | JSON 容器 | `tags: [Tag]` |
| `Tag.swift` | 标签数据模型 | **新文件** `Tag` + `TagColor` |
| `TodoStore.swift` | 状态管理 | 历史栈、批量操作、标签 CRUD、拖拽排序 |
| `ContentView.swift` | 主界面 | 多选、统计面板、标签过滤、标签管理 Sheet |
| `TodoRow.swift` | 任务行视图 | 到期日期标签、标签徽章、右键菜单 |

### 目录结构（Phase 7 最终）

```
TodoTool/
├── TodoToolApp.swift           # 应用入口 + 菜单命令
├── Notifications.swift         # 跨层通信通知定义
├── TodoTool.entitlements       # App Sandbox 配置
├── Models/
│   ├── Todo.swift              # 任务模型（含优先级、到期日期、标签）
│   ├── TodoData.swift          # JSON 容器（含标签数组）
│   └── Tag.swift               # 标签模型 + 颜色枚举
├── Store/
│   └── TodoStore.swift         # 状态管理 + 历史栈 + 批量操作
└── Views/
    ├── ContentView.swift       # 主界面 + 多选 + 标签管理
    ├── Components/
    │   ├── SearchFilterBar.swift    # 搜索与过滤条
    │   ├── BatchActionsBar.swift    # 批量操作条
    │   └── PriorityFilter.swift     # 过滤枚举（供视图共用）
    └── TodoRow.swift           # 任务行 + 到期日期 + 标签徽章

TodoToolTests/
├── TodoModelTests.swift        # 数据模型测试
└── TodoStoreTests.swift        # 持久化 + 业务逻辑测试
```

---

*文档版本: v9.3 | 更新时间: 2026-01-11*

---

## Phase 8: 四象限分类架构

### 四象限概念模型

```
                    紧急 (Urgent)
                         │
        Q1               │               Q3
   ┌─────────────────────┼─────────────────────┐
   │                     │                     │
   │  🔴 重要且紧急       │  🟡 不重要但紧急     │
   │  Do First           │  Delegate           │
   │  立即执行            │  考虑委托           │
   │                     │                     │
重要├─────────────────────┼─────────────────────┤不重要
   │                     │                     │
   │  🟠 重要但不紧急     │  ⚪ 不重要不紧急     │
   │  Schedule           │  Eliminate          │
   │  计划安排            │  考虑删除           │
   │                     │                     │
   └─────────────────────┼─────────────────────┘
        Q2               │               Q4
                         │
                    不紧急 (Not Urgent)
```

### 数据模型扩展

```
┌─────────────────────────────────────────────────────────────────┐
│                          Todo                                    │
│                                                                  │
│  现有字段                                                        │
│  ├── priority: Priority      ◄── 用于判断「重要性」              │
│  └── dueDate: Date?          ◄── 用于判断「紧急性」              │
│                                                                  │
│  新增计算属性（不持久化）                                         │
│  ├── isImportant: Bool       ◄── priority ∈ {.high, .medium}   │
│  ├── isUrgent: Bool          ◄── dueDate != nil && dueDate ≤ today│
│  └── quadrant: Quadrant      ◄── 根据以上两个属性计算            │
└─────────────────────────────────────────────────────────────────┘
```

### Quadrant 枚举设计

```swift
enum Quadrant: String, CaseIterable, Identifiable {
    case urgentImportant        // Q1: 🔴 重要且紧急
    case notUrgentImportant     // Q2: 🟠 重要但不紧急
    case urgentNotImportant     // Q3: 🟡 不重要但紧急
    case notUrgentNotImportant  // Q4: ⚪ 不重要且不紧急

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .urgentImportant: return "重要且紧急"
        case .notUrgentImportant: return "重要但不紧急"
        case .urgentNotImportant: return "不重要但紧急"
        case .notUrgentNotImportant: return "不重要且不紧急"
        }
    }

    var actionHint: String {
        switch self {
        case .urgentImportant: return "立即执行"
        case .notUrgentImportant: return "计划安排"
        case .urgentNotImportant: return "考虑委托"
        case .notUrgentNotImportant: return "考虑删除"
        }
    }

    var color: Color {
        switch self {
        case .urgentImportant: return .red
        case .notUrgentImportant: return .orange
        case .urgentNotImportant: return .yellow
        case .notUrgentNotImportant: return .gray
        }
    }

    /// 网格布局顺序（左上 → 右上 → 左下 → 右下）
    static var gridOrder: [Quadrant] {
        [.urgentImportant, .notUrgentImportant,
         .urgentNotImportant, .notUrgentNotImportant]
    }
}
```

### 视图架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        ContentView                               │
│                                                                  │
│  @State currentViewMode: ViewMode                               │
│  ├── .list      → 显示 taskListView（现有列表视图）             │
│  └── .quadrant  → 显示 QuadrantView（四象限视图）               │
│                                                                  │
│  工具栏                                                          │
│  └── 视图切换按钮 (list.bullet / square.grid.2x2)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       QuadrantView                               │
│                                                                  │
│  @ObservedObject todoStore: TodoStore                           │
│                                                                  │
│  LazyVGrid(columns: 2) {                                        │
│      ForEach(Quadrant.gridOrder) { quadrant in                  │
│          QuadrantCard(                                          │
│              quadrant: quadrant,                                │
│              todos: todoStore.todosByQuadrant[quadrant] ?? []   │
│          )                                                      │
│      }                                                          │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       QuadrantCard                               │
│                                                                  │
│  象限标题栏（颜色标识 + 名称 + 计数 + 策略提示）                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  🔴 重要且紧急 (3)                          立即执行        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  任务列表（ScrollView）                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  QuadrantTodoRow(todo: ...)                                 ││
│  │  QuadrantTodoRow(todo: ...)                                 ││
│  │  QuadrantTodoRow(todo: ...)                                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  空状态                                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  暂无任务                                                   ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 跨象限拖拽逻辑

```
┌─────────────────────────────────────────────────────────────────┐
│                      拖拽目标象限                                │
│                                                                  │
│  源象限 → 目标象限           属性变更                           │
│  ────────────────────────────────────────────────────────────   │
│  任意 → Q1 (紧急+重要)      priority = .high, dueDate = today  │
│  任意 → Q2 (不紧急+重要)    priority = .high, dueDate = nil    │
│  任意 → Q3 (紧急+不重要)    priority = .none, dueDate = today  │
│  任意 → Q4 (不紧急+不重要)  priority = .none, dueDate = nil    │
│                                                                  │
│  注意：跨象限拖拽会同时更新 priority 和 dueDate                 │
└─────────────────────────────────────────────────────────────────┘
```

### 目录结构（Phase 8 预览）

```
TodoTool/
├── TodoToolApp.swift           # 应用入口 + 菜单命令
├── Notifications.swift         # 通知定义（新增 .toggleQuadrantView）
├── TodoTool.entitlements       # App Sandbox 配置
├── Models/
│   ├── Todo.swift              # 任务模型（新增 isImportant/isUrgent/quadrant）
│   ├── TodoData.swift          # JSON 容器
│   ├── Tag.swift               # 标签模型
│   └── Quadrant.swift          # 四象限枚举（新增）
├── Store/
│   └── TodoStore.swift         # 状态管理（新增 todosByQuadrant）
└── Views/
    ├── ContentView.swift       # 主界面（新增视图切换）
    ├── TodoRow.swift           # 列表视图任务行
    ├── QuadrantView.swift      # 四象限主视图（新增）
    └── QuadrantCard.swift      # 象限卡片组件（新增）

TodoToolTests/
├── TodoModelTests.swift
├── TodoStoreTests.swift
└── QuadrantTests.swift         # 四象限逻辑测试（新增）
```

### 为什么使用计算属性而非持久化字段？

| 方案 | 优点 | 缺点 |
|------|------|------|
| **计算属性**（当前） | 零数据冗余、自动同步、向后兼容 | 每次访问需计算 |
| 持久化字段 | 读取快 | 数据冗余、需同步维护 |

**结论**：象限分类是 priority 和 dueDate 的派生状态，使用计算属性更符合「单一数据源」原则。

### 紧急性判断的边界条件

```
时间线:
──────────────────────────────────────────────────────────────────
       昨天          今天           明天          后天
         │            │              │             │
         │   ◄─ 紧急 ─┼─ 紧急 ─►    │             │
         │            │              │             │
    dueDate < today   │   dueDate    │  dueDate    │  dueDate
       = 紧急         │   = today    │  = tomorrow │  > tomorrow
       (已过期)       │   = 紧急     │  = 不紧急   │  = 不紧急
                      │              │             │
──────────────────────────────────────────────────────────────────

判断逻辑：
isUrgent = dueDate != nil && Calendar.current.isDateInToday(dueDate)
                          || dueDate < Calendar.current.startOfDay(for: Date())
```

---

*文档版本: v10.0 | 更新时间: 2026-01-11*

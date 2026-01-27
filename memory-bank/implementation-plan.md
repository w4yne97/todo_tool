# Todo Tool 实施计划

> **目标**：按照设计文档构建一个零依赖、极简健壮的 macOS Todo 应用
> **受众**：AI 开发者（Claude / Cursor / Copilot 等）
> **原则**：每步小而具体、必须可验证、禁止包含代码

---

## 关键决策记录

> 以下决策已确认，实施时必须遵循：

| 领域 | 决策 | 说明 |
|------|------|------|
| **Sandbox** | 开启 | 使用系统管理的容器路径，无需手动设置权限 |
| **测试目标** | 仅 Unit Testing Bundle | UI Test 留到 Phase 2 |
| **日期格式** | 自定义 ISO8601 formatter | 支持毫秒可选，避免解码失败 |
| **标题长度** | Unicode 字符数 (`.count`) | 200 = 200 个字符，中英文同等计算 |
| **版本迁移** | MVP 不实现 | 固定 `version = 1`，后续按需扩展 |
| **backup 策略** | 单版本覆盖 | 每次写入覆盖 `.backup`，不保留历史 |
| **load() 时机** | `init()` 中同步调用 | 确保 TodoStore 初始化后数据即可用 |
| **加载失败处理** | 记录日志并回退备份 | 主数据损坏时回退 backup，不再静默失败 |
| **列表缓存** | 过滤排序结果缓存 | 参数/数据不变时直接命中缓存，写操作失效缓存 |
| **新增任务 UI** | Sheet + TextField | MVP 最简实现，后续可改进 |
| **删除确认** | 必需 | 遵循设计文档要求 |
| **点击行为** | 单击任意位置 = 勾选 | 双击编辑留到 Phase 6 |
| **排序逻辑** | View 层 computed property | 保持 TodoStore 数据原样，View 负责展示排序 |
| **错误提示** | 系统 Alert | MVP 使用，Phase 2 改为 Toast |
| **乐观更新** | MVP 不实现 | 同步操作，失败直接报错 |

---

## Phase 0: 项目初始化

### Step 0.1 创建 Xcode 项目

**指令**：
1. 使用 Xcode 15+ 创建新项目
2. 选择模板：macOS → App
3. 项目配置：
   - Product Name: `TodoTool`
   - Team: 个人开发者账号（或留空）
   - Organization Identifier: `com.yourname`
   - Interface: SwiftUI
   - Language: Swift
   - 取消勾选 "Include Tests"（后续手动添加）
4. Deployment Target 设为 macOS 14.0

**验证**：
- [ ] 项目可编译通过（⌘B 无错误）
- [ ] 运行（⌘R）能显示默认 "Hello, World!" 窗口
- [ ] Bundle Identifier 格式正确：`com.yourname.TodoTool`

---

### Step 0.2 建立目录结构

**指令**：
1. 在项目根目录下创建以下文件夹（Group with Folder）：
   - `Models/`
   - `Store/`
   - `Views/`
2. 将 Xcode 自动生成的 `ContentView.swift` 移动到 `Views/` 目录
3. 删除任何不需要的模板文件（如 Preview Content 中的占位资源）

**验证**：
- [ ] Xcode 项目导航器显示正确的层级结构
- [ ] 编译通过，应用仍可正常运行
- [ ] 文件夹在 Finder 中物理存在（非虚拟 Group）

---

### Step 0.3 添加 CLAUDE.md 项目文档

**指令**：
1. 在项目根目录（与 `TodoTool.xcodeproj` 同级）创建 `CLAUDE.md`
2. 记录当前目录结构、架构决策、开发规范
3. 此文件作为 AI 开发者的上下文来源，需保持与代码同步

**验证**：
- [ ] `CLAUDE.md` 文件存在且包含基础架构说明
- [ ] 文件已添加到 Git 追踪（若使用版本控制）

---

## Phase 1: 数据模型层

### Step 1.1 定义 Todo 数据模型

**指令**：
1. 在 `Models/` 目录创建 `Todo.swift`
2. 定义 `Todo` 结构体，遵循 `Codable`、`Identifiable`、`Equatable` 协议
3. 必须包含以下属性：
   - `id`: UUID（唯一标识，使用 `let`）
   - `title`: String（非空，最大 200 字符）
   - `isCompleted`: Bool（完成状态）
   - `createdAt`: Date（创建时间，使用 `let`）
   - `completedAt`: Date?（完成时间，可选）
   - `updatedAt`: Date（最近修改时间）
4. 日期编解码使用 ISO8601 格式（UTC）

**验证**：
- [ ] 编译通过
- [ ] 可以创建 Todo 实例：`Todo(id: UUID(), title: "测试", isCompleted: false, createdAt: Date(), completedAt: nil, updatedAt: Date())`
- [ ] Todo 可以被编码为 JSON 字符串
- [ ] JSON 字符串可以被解码回 Todo 实例

---

### Step 1.2 定义存储数据容器

**指令**：
1. 在 `Models/` 目录创建 `TodoData.swift`（或在 `Todo.swift` 中追加）
2. 定义 `TodoData` 结构体，遵循 `Codable`
3. 包含属性：
   - `version`: Int（数据版本号，初始值为 1）
   - `todos`: [Todo]（任务数组）
4. 提供一个静态属性 `empty`，返回空的初始数据

**验证**：
- [ ] 编译通过
- [ ] `TodoData.empty.version == 1`
- [ ] `TodoData.empty.todos.isEmpty == true`
- [ ] 可序列化为设计文档中描述的 JSON 格式

---

### Step 1.3 添加数据模型单元测试

**指令**：
1. 在 Xcode 中添加测试目标：File → New → Target → Unit Testing Bundle
2. 命名为 `TodoToolTests`
3. 创建 `TodoModelTests.swift`
4. 编写测试用例：
   - 测试 Todo 创建：验证所有属性正确初始化
   - 测试 JSON 编码：验证输出格式符合设计文档
   - 测试 JSON 解码：验证可以从标准 JSON 恢复
   - 测试日期格式：验证使用 ISO8601 UTC 格式
   - 测试边界：空标题应被视为无效（后续在 Store 层处理）

**验证**：
- [ ] 所有测试用例通过（⌘U）
- [ ] 测试覆盖序列化/反序列化往返一致性

---

## Phase 2: 持久化层

### Step 2.1 创建 TodoStore 基础结构

**指令**：
1. 在 `Store/` 目录创建 `TodoStore.swift`
2. 定义 `TodoStore` 类，遵循 `ObservableObject` 协议
3. 添加 `@Published var todos: [Todo] = []` 属性
4. 定义文件路径常量：
   - 数据目录：`~/Library/Application Support/TodoTool/`
   - 主文件：`data.json`
   - 备份文件：`data.json.backup`
   - 临时文件：`data.json.tmp`
5. 在 `init()` 中创建数据目录（如不存在）

**验证**：
- [ ] 编译通过
- [ ] 实例化 TodoStore 后，数据目录被创建
- [ ] 路径使用 FileManager 标准 API 构建

---

### Step 2.2 实现数据读取逻辑

**指令**：
1. 在 TodoStore 中实现 `load()` 方法
2. 读取逻辑按优先级：
   - 首先尝试读取 `data.json`
   - 若失败或损坏，尝试读取 `data.json.backup`
   - 若都失败，使用 `TodoData.empty` 初始化
3. 解码使用 JSONDecoder，日期策略设为 `.iso8601`
4. 加载失败需输出日志；主文件损坏回退备份，备份损坏则落空数据
5. 加载完成后更新 `todos` 属性

**验证**：
- [ ] 无数据文件时，`todos` 为空数组
- [ ] 有效 JSON 文件被正确加载
- [ ] 损坏的主文件会回退到备份
- [ ] 完全无法恢复时创建空数据，不崩溃

---

### Step 2.3 实现原子写入逻辑

**指令**：
1. 在 TodoStore 中实现 `save()` 方法
2. 写入步骤（原子性保证）：
   - Step A: 将数据编码为 JSON
   - Step B: 写入临时文件 `data.json.tmp`
   - Step C: 若主文件存在，重命名为 `data.json.backup`
   - Step D: 重命名 `data.json.tmp` 为 `data.json`
3. 任何步骤失败时：
   - 清理临时文件
   - 尝试从 backup 恢复
   - 抛出错误供上层处理
4. 编码使用 JSONEncoder，日期策略 `.iso8601`，输出格式化（`.prettyPrinted`）

**验证**：
- [ ] 保存后文件内容与内存数据一致
- [ ] `data.json.backup` 包含上一次成功保存的数据
- [ ] 模拟写入中断（如磁盘满），数据不丢失

---

### Step 2.4 添加持久化单元测试

**指令**：
1. 创建 `TodoStoreTests.swift`
2. 使用临时目录进行测试，避免污染用户数据
3. 测试用例：
   - 测试空目录初始化：应创建目录，返回空数据
   - 测试正常保存/加载：往返一致
   - 测试备份恢复：删除主文件后应从 backup 恢复
   - 测试损坏恢复：主文件和备份都损坏时返回空数据
   - 测试原子性：写入过程中断不应损坏已有数据

**验证**：
- [ ] 所有测试用例通过
- [ ] 测试使用隔离的临时目录
- [ ] 测试后清理临时文件

---

## Phase 3: 业务逻辑层

### Step 3.1 实现添加任务功能

**指令**：
1. 在 TodoStore 中实现 `add(title: String)` 方法
2. 逻辑：
   - 验证 title 非空且长度 ≤ 200
   - 创建新 Todo 实例，所有时间戳设为当前时间
   - 将新任务插入到 `todos` 数组开头
   - 调用 `save()` 持久化
3. 验证失败时抛出明确错误

**验证**：
- [ ] 添加后 `todos.count` 增加 1
- [ ] 新任务出现在数组第一位
- [ ] 空标题被拒绝
- [ ] 超长标题被拒绝
- [ ] 数据文件已更新

---

### Step 3.2 实现完成状态切换功能

**指令**：
1. 在 TodoStore 中实现 `toggle(id: UUID)` 方法
2. 逻辑：
   - 找到对应 ID 的任务
   - 切换 `isCompleted` 状态
   - 更新 `updatedAt` 为当前时间
   - 若切换为完成，设置 `completedAt`；若切换为未完成，清除 `completedAt`
   - 调用 `save()` 持久化
3. ID 不存在时静默忽略（或记录日志）

**验证**：
- [ ] 未完成 → 完成：`isCompleted` 变为 true，`completedAt` 有值
- [ ] 完成 → 未完成：`isCompleted` 变为 false，`completedAt` 为 nil
- [ ] `updatedAt` 已更新
- [ ] 数据文件已更新

---

### Step 3.3 实现删除任务功能

**指令**：
1. 在 TodoStore 中实现 `delete(id: UUID)` 方法
2. 逻辑：
   - 从 `todos` 数组中移除对应 ID 的任务
   - 调用 `save()` 持久化
3. ID 不存在时静默忽略

**验证**：
- [ ] 删除后 `todos.count` 减少 1
- [ ] 被删除的任务不再存在于数组中
- [ ] 数据文件已更新
- [ ] 删除不存在的 ID 不会崩溃

---

### Step 3.4 实现编辑任务标题功能

**指令**：
1. 在 TodoStore 中实现 `update(id: UUID, title: String)` 方法
2. 逻辑：
   - 验证新标题非空且长度 ≤ 200
   - 找到对应任务，更新 `title`
   - 更新 `updatedAt` 为当前时间
   - 调用 `save()` 持久化

**验证**：
- [ ] 标题已更新
- [ ] `updatedAt` 已更新
- [ ] 空标题被拒绝
- [ ] 数据文件已更新

---

### Step 3.5 添加业务逻辑单元测试

**指令**：
1. 在 `TodoStoreTests.swift` 中追加测试用例
2. 测试：
   - 添加任务：验证数量、顺序、持久化
   - 完成切换：验证状态、时间戳、持久化
   - 删除任务：验证移除、持久化
   - 编辑任务：验证内容、时间戳、持久化
   - 边界条件：空标题、超长标题、不存在的 ID

**验证**：
- [ ] 所有测试用例通过
- [ ] 每个操作都验证了持久化结果

---

## Phase 4: 视图层（基础 UI）

### Step 4.1 创建单行任务视图

**指令**：
1. 在 `Views/` 目录创建 `TodoRow.swift`
2. 定义 `TodoRow` 视图，接收 `Todo` 和必要的回调
3. 显示内容：
   - 左侧：完成状态图标（未完成用空心圆，已完成用勾选）
   - 中间：任务标题（已完成时显示删除线样式）
   - 右侧（可选）：已完成任务显示完成时间
4. 点击整行触发完成状态切换回调

**验证**：
- [ ] 编译通过
- [ ] 在 Preview 中可以看到未完成和已完成两种状态
- [ ] 视觉样式符合设计文档线框图

---

### Step 4.2 创建主界面基础结构

**指令**：
1. 重写 `Views/ContentView.swift`
2. 使用 `@StateObject` 持有 TodoStore 实例
3. 界面结构：
   - 顶部：标题栏 + 新增按钮
   - 中间：任务列表（使用 List 或 ScrollView + LazyVStack）
   - 底部：（暂时留空）
4. 任务列表分为两个 Section：
   - 待办（isCompleted == false）
   - 已完成（isCompleted == true）
5. 每个 Section 显示计数

**验证**：
- [ ] 编译通过并能显示界面
- [ ] 添加的任务出现在正确的分组中
- [ ] 分组标题显示正确的数量

---

### Step 4.3 实现新增任务交互

**指令**：
1. 点击新增按钮后显示输入区域（可使用 Sheet、Alert with TextField、或行内输入）
2. 用户输入标题后，调用 `todoStore.add(title:)`
3. 输入为空时禁用确认按钮或显示提示
4. 添加成功后：
   - 关闭输入区域
   - 列表自动显示新任务

**验证**：
- [ ] 点击新增按钮能打开输入界面
- [ ] 输入内容后能成功添加任务
- [ ] 任务出现在列表顶部
- [ ] 空输入被阻止

---

### Step 4.4 实现完成状态切换交互

**指令**：
1. 点击 TodoRow 或其复选框区域时，调用 `todoStore.toggle(id:)`
2. 界面立即反映状态变化（乐观更新）
3. 完成的任务移动到"已完成"分组

**验证**：
- [ ] 点击未完成任务，状态变为已完成
- [ ] 点击已完成任务，状态变为未完成
- [ ] 任务在正确的分组中显示
- [ ] UI 响应流畅，无明显延迟

---

### Step 4.5 实现删除任务交互

**指令**：
1. 支持滑动删除（SwiftUI List 的 `.onDelete` 修饰符）
2. 删除前显示确认（可选，根据设计文档要求）
3. 调用 `todoStore.delete(id:)` 执行删除

**验证**：
- [ ] 滑动行能显示删除按钮
- [ ] 点击删除后任务从列表消失
- [ ] 刷新应用后任务仍然被删除（持久化生效）

---

### Step 4.6 实现空状态展示

**指令**：
1. 当 `todos` 为空时，显示引导界面
2. 引导内容：
   - 友好的提示文案（如"暂无任务，点击添加"）
   - 一个新增按钮
3. 样式居中、柔和，符合空状态设计最佳实践

**验证**：
- [ ] 无任务时显示空状态界面
- [ ] 有任务时显示正常列表
- [ ] 点击空状态的新增按钮能添加任务

---

### Step 4.7 更新应用入口

**指令**：
1. 修改 `TodoToolApp.swift`
2. 设置主窗口使用 ContentView
3. 配置窗口属性：
   - 合适的默认尺寸（如 400x600）
   - 合理的最小尺寸限制
4. 确保应用单实例运行

**验证**：
- [ ] 应用启动显示主界面
- [ ] 窗口尺寸合适
- [ ] 关闭窗口后应用退出（标准 macOS 行为）

---

## Phase 5: 完整性验证

### Step 5.1 端到端功能测试

**指令**：
1. 手动执行完整测试流程：
   - 首次启动：应显示空状态
   - 添加 3 个任务：验证顺序（最新在最前）
   - 完成其中 1 个：验证移动到已完成分组
   - 取消完成：验证返回待办分组
   - 删除 1 个任务：验证从列表消失
   - 退出并重启：验证数据持久化
2. 检查数据文件内容是否符合设计格式

**验证**：
- [ ] 所有操作按预期工作
- [ ] 数据重启后完整保留
- [ ] `data.json` 格式正确可读

---

### Step 5.2 异常场景测试

**指令**：
1. 测试异常恢复：
   - 删除 `data.json`，保留 `data.json.backup`，重启应用
   - 损坏 `data.json`（写入乱码），重启应用
   - 删除整个数据目录，重启应用
2. 每种情况应用都应正常启动，不崩溃

**验证**：
- [ ] 备份恢复有效
- [ ] 损坏文件被忽略，从备份恢复
- [ ] 无任何数据时创建空数据

---

### Step 5.3 性能基准测试

**指令**：
1. 测量冷启动时间（使用 Instruments 或手动计时）
2. 目标：首帧 < 200ms
3. 测量内存占用
4. 若不达标，分析瓶颈并优化

**验证**：
- [ ] 冷启动时间符合要求
- [ ] 内存占用合理（通常 < 50MB）

---

### Step 5.4 更新文档

**指令**：
1. 更新 `CLAUDE.md`：
   - 记录最终目录结构
   - 记录关键设计决策
   - 记录任何与设计文档的偏差及原因
2. 验证所有文件有清晰的职责说明

**验证**：
- [ ] 文档与代码一致
- [ ] 新开发者可通过文档理解项目结构

---

## Phase 6: 体验增强（后续迭代）

> 以下步骤在 MVP 完成后按需实施

### Step 6.1 快捷键支持

**指令**：
1. 添加全局快捷键：
   - ⌘N：新建任务
   - ⌘⌫：删除选中任务
   - Enter/Space：切换完成状态
   - Esc：取消编辑

**验证**：
- [ ] 快捷键在主窗口获得焦点时生效
- [ ] 与系统快捷键无冲突

---

### Step 6.2 行内编辑

**指令**：
1. 双击任务标题进入编辑模式
2. Enter 确认，Esc 取消
3. 编辑时显示边框或高亮

**验证**：
- [ ] 双击可进入编辑
- [ ] 修改后持久化
- [ ] 取消不保存修改

---

### Step 6.3 动画与过渡

**指令**：
1. 添加任务时的插入动画
2. 删除任务时的移除动画
3. 完成状态切换时的过渡效果
4. 确保动画流畅，不掉帧

**验证**：
- [ ] 动画自然流畅
- [ ] 不影响应用响应速度

---

### Step 6.4 导出功能

**指令**：
1. 在菜单栏添加「文件 → 导出…」
2. 允许用户选择保存位置
3. 导出为格式化的 JSON 文件

**验证**：
- [ ] 菜单项可点击
- [ ] 导出文件内容正确
- [ ] 导出文件可被应用重新导入（作为备份恢复）

---

## 附录：验收清单总览

| 阶段 | 核心验收点 |
|------|------------|
| Phase 0 | 项目结构正确，编译运行通过 |
| Phase 1 | 数据模型可序列化，单测通过 |
| Phase 2 | 原子写入工作，异常恢复有效 |
| Phase 3 | CRUD 操作正确，持久化生效 |
| Phase 4 | UI 可交互，视觉符合设计 |
| Phase 5 | 端到端测试通过，性能达标 |
| Phase 6 | 增强功能按需完成 |

---

*计划版本: v1.0 | 生成时间: 2026-01-09*

---

## Phase 7: 功能增强（规划中）

> 在保持「零依赖、本地优先」理念的前提下，增强实用性和用户体验

### 高优先级

#### Step 7.1 深色模式

**指令**：
1. 验证当前 SwiftUI 语义化颜色已自动适配深色模式
2. 如需自定义颜色，在 Asset Catalog 定义 Light/Dark 变体
3. （可选）添加手动切换菜单：视图 → 外观

**验证**：
- [ ] 系统切换深色模式后应用自动适配
- [ ] 所有文字和图标在深色背景下可读

---

#### Step 7.2 搜索过滤

**指令**：
1. 在顶部标题栏下方添加搜索框
2. 实时过滤显示匹配标题的任务
3. 添加快捷键 ⌘F 聚焦搜索框

**数据处理**：
```swift
var filteredTodos: [Todo] {
    searchText.isEmpty ? todos : todos.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
}
```

**验证**：
- [ ] 输入关键词实时过滤任务
- [ ] ⌘F 聚焦搜索框
- [ ] 清空搜索框显示全部任务

---

#### Step 7.3 优先级标记

**指令**：
1. 在 `Todo` 模型添加 `priority: Priority` 字段
2. 定义 `Priority` 枚举：`none`, `low`, `medium`, `high`
3. TodoRow 左侧显示彩色优先级圆点
4. 添加快捷键 ⌘0/1/2/3 设置优先级

**验证**：
- [ ] 任务显示优先级颜色标记
- [ ] 快捷键可设置/清除优先级
- [ ] 优先级持久化到 data.json

---

#### Step 7.4 导入功能

**指令**：
1. 添加菜单项：文件 → 导入数据…（⌘I）
2. 使用 NSOpenPanel 选择 JSON 文件
3. 提供选项：覆盖 / 合并（跳过重复 ID）
4. 显示导入结果

**验证**：
- [ ] 可导入之前导出的 JSON 文件
- [ ] 合并模式不覆盖现有任务
- [ ] 无效文件显示错误提示

---

#### Step 7.5 撤销/重做

**指令**：
1. 在 TodoStore 中维护历史栈（快照需包含 todos + tags）
2. 每次 CRUD/标签操作后 `saveState()`
3. 实现 `undo()` 和 `redo()` 方法
4. 添加菜单项和快捷键 ⌘Z / ⌘⇧Z

**验证**：
- [ ] 删除任务后 ⌘Z 可恢复
- [ ] ⌘⇧Z 重做已撤销的操作
- [ ] 历史栈有大小限制（如 50 步）

---

### 中优先级

#### Step 7.6 统计面板

**指令**：
1. 在窗口底部添加状态栏
2. 显示：待办 X 个 | 已完成 Y 个 | 今日完成 Z 个

**验证**：
- [ ] 计数实时更新
- [ ] 跨越午夜后「今日完成」重置

---

#### Step 7.7 到期日期

**指令**：
1. 在 `Todo` 模型添加 `dueDate: Date?` 字段
2. 任务行显示到期日期（过期红色、临近黄色）
3. 右键菜单或双击日期设置

**验证**：
- [ ] 可设置/清除到期日期
- [ ] 过期任务红色高亮
- [ ] 日期持久化

---

#### Step 7.8 拖拽排序

**指令**：
1. 在 `Todo` 模型添加 `sortOrder: Int` 字段
2. 使用 `.onMove` 修饰符支持拖拽
3. 拖拽后更新 sortOrder 并保存
4. 拖拽仅允许同优先级，跨优先级直接拒绝（View+Store 双校验）
5. 排序值过大/间距过小时触发归一化（阈值：差值>10000 或绝对值越界）

**验证**：
- [ ] 长按拖拽可调整顺序（同优先级）
- [ ] 跨优先级拖拽被拒绝
- [ ] 顺序重启后保留
- [ ] 频繁拖拽后排序仍稳定无溢出

---

#### Step 7.9 批量操作

**指令**：
1. 支持 ⌘+点击 多选
2. 选中多个后显示操作按钮
3. 添加菜单：编辑 → 清除已完成（⌘⇧K）

**验证**：
- [ ] 可多选任务
- [ ] 批量完成/删除正常工作

---

#### Step 7.10 标签分类

**指令**：
1. 创建 `Tag` 模型（id, name, color）
2. 在 `Todo` 中添加 `tagIds: [UUID]`
3. 更新 `TodoData` 包含 `tags` 数组
4. UI 支持标签管理和过滤

**验证**：
- [ ] 可创建/编辑/删除标签
- [ ] 任务可关联多个标签
- [ ] 按标签过滤任务

---

#### Step 7.11 任务描述与增强日期选择器

**指令**：
1. 在 `Todo` 模型新增 `description: String`，默认空字符串，编解码向后兼容。
2. 新建任务弹窗使用多行输入（`TextEditor`），支持换行与长文本裁剪。
3. 列表行在标题下方显示描述预览，进入编辑模式可同时修改标题和描述。
4. 到期日期选择：保留「今天/明天/下周」快捷选项，新增图形化日期选择器（Popover），提供清除按钮，应用时统一写入当天 23:59:59。

**验证**：
- [ ] 描述在添加、编辑、持久化、列表展示全链路可用。
- [ ] 快捷日期与日历选择结果一致，清除后状态恢复为无日期。
- [ ] 所有日期存储为当天 23:59:59（避免时间偏移）。

---

## 附录：验收清单总览（更新）

| 阶段 | 核心验收点 | 状态 |
|------|------------|------|
| Phase 0 | 项目结构正确，编译运行通过 | ✅ |
| Phase 1 | 数据模型可序列化，单测通过 | ✅ |
| Phase 2 | 原子写入工作，异常恢复有效 | ✅ |
| Phase 3 | CRUD 操作正确，持久化生效 | ✅ |
| Phase 4 | UI 可交互，视觉符合设计 | ✅ |
| Phase 5 | 端到端测试通过，性能达标 | ✅ |
| Phase 6 | 体验增强功能完成 | ✅ |
| Phase 7 | 功能增强 | ✅ |
| Phase 8 | 任务描述 + 增强日期选择器 | ✅ |

---

## Phase 8: 四象限分类视图

> 实现艾森豪威尔矩阵（Eisenhower Matrix），提供任务按「重要性 × 紧急性」的可视化分类

### 设计原则

1. **复用现有字段**：使用 `priority` 表示重要性，`dueDate` 表示紧急性，不新增持久化字段
2. **计算属性驱动**：分类逻辑通过 `Quadrant` 枚举和计算属性实现
3. **视图独立**：四象限视图作为独立页面，与列表视图可切换
4. **交互一致**：象限内任务操作与列表视图保持一致

### 四象限定义

| 象限 | 条件 | 策略 | 颜色 |
|------|------|------|------|
| Q1: 重要且紧急 | priority ∈ {high, medium} AND dueDate ≤ today | Do（立即执行） | 红色 |
| Q2: 重要但不紧急 | priority ∈ {high, medium} AND (dueDate > today OR nil) | Schedule（计划安排） | 橙色 |
| Q3: 不重要但紧急 | priority ∈ {low, none} AND dueDate ≤ today | Delegate（考虑委托） | 黄色 |
| Q4: 不重要且不紧急 | priority ∈ {low, none} AND (dueDate > today OR nil) | Eliminate（考虑删除） | 灰色 |

---

### Step 8.1 四象限数据模型扩展

**指令**：
1. 在 `Models/` 目录创建 `Quadrant.swift`
2. 定义 `Quadrant` 枚举：
   ```swift
   enum Quadrant: String, CaseIterable {
       case urgentImportant       // Q1: 重要且紧急
       case notUrgentImportant    // Q2: 重要但不紧急
       case urgentNotImportant    // Q3: 不重要但紧急
       case notUrgentNotImportant // Q4: 不重要且不紧急

       var displayName: String { ... }
       var color: Color { ... }
       var actionHint: String { ... }  // "立即执行" / "计划安排" 等
   }
   ```
3. 在 `Todo` 扩展中添加计算属性：
   - `isImportant: Bool` - priority ∈ {.high, .medium}
   - `isUrgent: Bool` - dueDate != nil && dueDate ≤ today
   - `quadrant: Quadrant` - 根据以上两个属性返回对应象限
4. 在 `TodoStore` 中添加：
   - `todosByQuadrant: [Quadrant: [Todo]]` - 按象限分组的待办任务
   - 只对未完成任务进行分类

**验证**：
- [ ] 编译通过
- [ ] 高优先级+今天到期 → Q1
- [ ] 高优先级+无到期日 → Q2
- [ ] 无优先级+今天到期 → Q3
- [ ] 无优先级+无到期日 → Q4
- [ ] 已完成任务不参与象限分类

---

### Step 8.2 四象限视图页面

**指令**：
1. 在 `Views/` 目录创建 `QuadrantView.swift`
2. 创建 `QuadrantCard.swift` 作为单个象限的卡片组件
3. 使用 2×2 网格布局展示四个象限：
   ```swift
   LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
       QuadrantCard(quadrant: .urgentImportant, todos: ...)
       QuadrantCard(quadrant: .notUrgentImportant, todos: ...)
       QuadrantCard(quadrant: .urgentNotImportant, todos: ...)
       QuadrantCard(quadrant: .notUrgentNotImportant, todos: ...)
   }
   ```
4. QuadrantCard 包含：
   - 象限标题 + 任务计数 + 颜色标识
   - 任务列表（ScrollView + ForEach）
   - 空状态提示

**验证**：
- [ ] 四象限正确布局
- [ ] 任务按象限分类显示
- [ ] 深色模式下颜色正确
- [ ] 窗口调整大小时布局自适应

---

### Step 8.3 页面导航与切换

**指令**：
1. 定义 `ViewMode` 枚举：`list` / `quadrant`
2. 在 `ContentView` 中添加 `@State currentViewMode: ViewMode`
3. 在顶部工具栏添加视图切换按钮（图标：list.bullet / square.grid.2x2）
4. 在 `TodoToolApp.swift` 添加菜单项：
   - 视图 → 四象限视图（⌘⇧Q）
5. 使用 `.transition` 实现切换动画
6. 在 `Notifications.swift` 添加 `.toggleQuadrantView` 通知

**验证**：
- [ ] 工具栏按钮可切换视图
- [ ] ⌘⇧Q 快捷键可切换
- [ ] 切换动画流畅
- [ ] 视图状态在会话内保持

---

### Step 8.4 象限内任务交互

**指令**：
1. 点击任务切换完成状态
2. 右键菜单复用 TodoRow 的逻辑（优先级、到期日期、标签等）
3. 实现跨象限拖拽：
   - 拖到「重要」区域 → 设置 priority = .high
   - 拖到「紧急」区域 → 设置 dueDate = today
   - 拖到「不重要」区域 → 设置 priority = .none
   - 拖到「不紧急」区域 → 清除 dueDate
4. 操作后任务自动重新分类

**验证**：
- [ ] 点击切换完成状态正常
- [ ] 右键菜单功能正常
- [ ] 跨象限拖拽正确更新属性
- [ ] 拖拽后任务移动到正确象限

---

### Step 8.5 快捷键与菜单支持

**指令**：
1. 添加快捷键：
   - ⌘⇧Q：切换四象限视图
   - Esc（四象限视图内）：返回列表视图
2. 更新菜单栏结构：
   ```
   视图
   ├── 外观 →
   └── 四象限视图 (⌘⇧Q)
   ```

**验证**：
- [ ] 快捷键正常工作
- [ ] 菜单显示正确
- [ ] 与现有快捷键无冲突

---

### Step 8.6 单元测试

**指令**：
1. 在 `TodoToolTests/` 创建 `QuadrantTests.swift`
2. 测试用例：
   - 象限分类逻辑（各种 priority/dueDate 组合）
   - 边界条件（今天 23:59:59、明天 00:00:00）
   - 已完成任务不参与分类
   - `todosByQuadrant` 分组正确性

**验证**：
- [ ] 所有测试用例通过
- [ ] 覆盖所有象限组合

---

## 附录：验收清单总览（更新）

| 阶段 | 核心验收点 | 状态 |
|------|------------|------|
| Phase 0 | 项目结构正确，编译运行通过 | ✅ |
| Phase 1 | 数据模型可序列化，单测通过 | ✅ |
| Phase 2 | 原子写入工作，异常恢复有效 | ✅ |
| Phase 3 | CRUD 操作正确，持久化生效 | ✅ |
| Phase 4 | UI 可交互，视觉符合设计 | ✅ |
| Phase 5 | 端到端测试通过，性能达标 | ✅ |
| Phase 6 | 体验增强功能完成 | ✅ |
| Phase 7 | 功能增强完成 | ✅ |
| **Phase 8** | **四象限分类视图** | 🔜 规划中 |

---

---

## Phase 10: 已完成分组折叠功能

### Step 10.1 已完成分组折叠/展开

**指令**：
1. 在 `ContentView` 中添加 `@AppStorage("com.todotool.completedCollapsed")` 属性
2. 将已完成 Section 的纯文本 header 替换为可点击的 Button
3. 使用 `chevron.right` + `rotationEffect` 提供折叠/展开视觉指示
4. 用 `if !isCompletedCollapsed` 条件渲染已完成任务列表

**验证**：
- [x] 已完成分组 header 显示 chevron 图标
- [x] 点击 header 可折叠/展开
- [x] chevron 旋转动画流畅
- [x] 折叠状态下 header 仍显示已完成计数
- [x] 退出并重启 app 后折叠状态保持
- [x] 搜索/过滤模式下折叠行为正常
- [x] 无已完成项时不显示已完成 section

---

*计划版本: v2.5 | 更新时间: 2026-01-27*

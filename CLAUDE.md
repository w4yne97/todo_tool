# TodoTool 项目文档

> 极简 macOS Todo 应用 —— 零依赖、本地优先、秒开秒用

---

## 架构概览

```
┌────────────────────────────────────┐
│              Views                  │
│  SwiftUI（ContentView, TodoRow）   │
└─────────────┬──────────────────────┘
              │ @StateObject
              ▼
┌────────────────────────────────────┐
│           TodoStore                 │
│  @Published todos: [Todo]          │
│  func add/toggle/delete/save()     │
└─────────────┬──────────────────────┘
              │ Codable
              ▼
┌────────────────────────────────────┐
│           JSON File                 │
│  ~/Library/.../TodoTool/data.json  │
└────────────────────────────────────┘
```

**设计哲学**：三层架构，无中间件。TodoStore 同时承担状态管理和持久化。

---

## 目录结构

```
TodoTool/
├── TodoToolApp.swift      # 应用入口（@main）
├── TodoTool.entitlements  # App Sandbox 配置
├── Models/                # 数据模型层
│   └── (Todo.swift)       # Phase 1 实现
├── Store/                 # 状态管理层
│   └── (TodoStore.swift)  # Phase 2 实现
└── Views/                 # 视图层
    ├── ContentView.swift  # 主界面
    └── (TodoRow.swift)    # Phase 4 实现
```

---

## 关键决策

| 领域 | 决策 | 理由 |
|------|------|------|
| Sandbox | 开启 | 系统管理容器路径，无需手动设置权限 |
| 存储 | JSON 文件 | 零依赖，Codable 原生支持，便于调试 |
| 日期格式 | ISO8601 UTC | 标准格式，跨时区安全 |
| 写入策略 | 原子替换 | tmp → backup → rename，防数据丢失 |
| 架构 | 三层极简 | View → Store → File，无过度抽象 |

---

## 数据存储

**位置**：`~/Library/Application Support/TodoTool/`

```
data.json          # 主数据文件
data.json.backup   # 上次成功写入的备份
data.json.tmp      # 写入中的临时文件
```

**格式**：
```json
{
  "version": 1,
  "todos": [
    {
      "id": "uuid",
      "title": "任务标题",
      "isCompleted": false,
      "createdAt": "2026-01-09T10:00:00Z",
      "completedAt": null,
      "updatedAt": "2026-01-09T10:00:00Z"
    }
  ]
}
```

---

## 开发规范

1. **零依赖原则**：仅使用系统内置框架（SwiftUI、Foundation）
2. **本地优先**：所有数据存储在本地，无需联网
3. **原子写入**：任何持久化操作必须保证数据完整性
4. **单一数据源**：TodoStore 持有唯一真相
5. **边界清晰**：View 只负责展示，Store 只负责逻辑

---

## 构建环境

| 项目 | 要求 |
|------|------|
| macOS | 14.0 Sonoma+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| 部署目标 | macOS 14.0 |

---

## 实施进度

- [x] Phase 0: 项目初始化
- [ ] Phase 1: 数据模型层
- [ ] Phase 2: 持久化层
- [ ] Phase 3: 业务逻辑层
- [ ] Phase 4: 视图层
- [ ] Phase 5: 完整性验证

---

*文档版本: v1.0 | 更新时间: 2026-01-09*

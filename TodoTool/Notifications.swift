// ==================== 通知名称定义 ====================
// 用于 App 级菜单命令与 View 层通信

import Foundation

// MARK: - 导入模式

/// 导入模式枚举（独立定义，避免循环依赖）
enum ImportMode: String {
    case replace  // 覆盖现有数据
    case merge    // 合并（跳过重复 ID）

    var displayName: String {
        switch self {
        case .replace: return "覆盖"
        case .merge: return "合并"
        }
    }
}

extension Notification.Name {
    /// 新建任务快捷键通知
    static let addTask = Notification.Name("com.todotool.addTask")

    /// 删除任务快捷键通知
    static let deleteTask = Notification.Name("com.todotool.deleteTask")

    /// 切换完成状态快捷键通知
    static let toggleTask = Notification.Name("com.todotool.toggleTask")

    /// 编辑选中任务快捷键通知
    static let editTask = Notification.Name("com.todotool.editTask")

    /// 导出数据通知
    static let exportData = Notification.Name("com.todotool.exportData")

    /// 聚焦搜索框快捷键通知
    static let focusSearch = Notification.Name("com.todotool.focusSearch")
    
    /// 设置优先级快捷键通知（userInfo["priority"] = Priority）
    static let setPriority = Notification.Name("com.todotool.setPriority")

    /// 数据已导入通知（通知 View 层刷新）
    static let dataImported = Notification.Name("com.todotool.dataImported")

    /// 导入数据请求通知（携带 ImportRequest 作为 userInfo）
    static let importDataRequest = Notification.Name("com.todotool.importDataRequest")

    /// 撤销操作快捷键通知
    static let undoAction = Notification.Name("com.todotool.undoAction")

    /// 重做操作快捷键通知
    static let redoAction = Notification.Name("com.todotool.redoAction")

    /// 清除已完成任务通知
    static let clearCompleted = Notification.Name("com.todotool.clearCompleted")

    /// 管理标签通知
    static let manageTags = Notification.Name("com.todotool.manageTags")

    /// 切换视图模式通知（列表/四象限）
    static let toggleViewMode = Notification.Name("com.todotool.toggleViewMode")
}

// MARK: - 导入请求数据

/// 导入请求结构，用于在 App 和 View 层之间传递导入参数
struct ImportRequest {
    let fileData: Data   // JSON 文件内容
    let mode: ImportMode // 导入模式
}

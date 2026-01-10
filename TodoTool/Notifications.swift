// ==================== 通知名称定义 ====================
// 用于 App 级菜单命令与 View 层通信

import Foundation

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
    
    /// 设置优先级快捷键通知（携带 Priority 作为 object）
    static let setPriority = Notification.Name("com.todotool.setPriority")
}

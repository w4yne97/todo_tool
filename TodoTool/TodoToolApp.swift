// ==================== TodoTool 应用入口 ====================
// 极简 macOS Todo 应用 - 零依赖、本地优先
// 菜单栏快捷键：⌘N 新建、⌘⌫ 删除、⌘E 导出、⌘F 搜索
// 支持深色模式：视图 → 外观

import SwiftUI
import AppKit

// ==================== 外观设置 ====================

/// 外观模式枚举
enum AppearanceMode: String, CaseIterable {
    case system = "system"  // 跟随系统
    case light = "light"    // 浅色模式
    case dark = "dark"      // 深色模式

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct TodoToolApp: App {
    /// 外观模式偏好（持久化到 UserDefaults）
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    /// 当前外观模式
    private var currentMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(currentMode.colorScheme)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 400, height: 600)
        .commands {
            // 替换系统的「新建」菜单项
            CommandGroup(replacing: .newItem) {
                Button("新建任务") {
                    NotificationCenter.default.post(name: .addTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // 文件菜单：导出功能
            CommandGroup(after: .newItem) {
                Divider()

                Button("导出数据…") {
                    exportData()
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            // 自定义编辑菜单
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("搜索任务") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("删除任务") {
                    NotificationCenter.default.post(name: .deleteTask, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Button("切换完成状态") {
                    NotificationCenter.default.post(name: .toggleTask, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
                
                Divider()
                
                // 优先级快捷键
                Menu("优先级") {
                    Button("无优先级") {
                        NotificationCenter.default.post(name: .setPriority, object: Priority.none)
                    }
                    .keyboardShortcut("0", modifiers: .command)
                    
                    Button("低优先级") {
                        NotificationCenter.default.post(name: .setPriority, object: Priority.low)
                    }
                    .keyboardShortcut("1", modifiers: .command)
                    
                    Button("中优先级") {
                        NotificationCenter.default.post(name: .setPriority, object: Priority.medium)
                    }
                    .keyboardShortcut("2", modifiers: .command)
                    
                    Button("高优先级") {
                        NotificationCenter.default.post(name: .setPriority, object: Priority.high)
                    }
                    .keyboardShortcut("3", modifiers: .command)
                }
            }

            // 视图菜单：外观设置
            CommandMenu("视图") {
                Menu("外观") {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            appearanceMode = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.displayName)
                                if currentMode == mode {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 导出功能

    /// 导出数据到用户选择的位置
    private func exportData() {
        // 获取数据目录
        guard let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            showAlert(title: "导出失败", message: "无法访问应用数据目录")
            return
        }

        let dataDirectory = appSupportURL.appendingPathComponent("TodoTool")
        let dataURL = dataDirectory.appendingPathComponent("data.json")

        // 读取数据文件
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            showAlert(title: "导出失败", message: "暂无数据可导出")
            return
        }

        guard let jsonData = try? Data(contentsOf: dataURL) else {
            showAlert(title: "导出失败", message: "无法读取数据文件")
            return
        }

        // 格式化 JSON（确保可读性）
        let formattedData: Data
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
           let prettyData = try? JSONSerialization.data(
               withJSONObject: jsonObject,
               options: [.prettyPrinted, .sortedKeys]
           ) {
            formattedData = prettyData
        } else {
            formattedData = jsonData
        }

        // 显示保存对话框
        let savePanel = NSSavePanel()
        savePanel.title = "导出待办事项"
        savePanel.nameFieldStringValue = "TodoTool_Export_\(dateString()).json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try formattedData.write(to: url)
                showAlert(title: "导出成功", message: "数据已导出到:\n\(url.path)")
            } catch {
                showAlert(title: "导出失败", message: "写入文件失败: \(error.localizedDescription)")
            }
        }
    }

    /// 生成日期字符串用于文件名
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    /// 显示提示对话框
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title.contains("失败") ? .warning : .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

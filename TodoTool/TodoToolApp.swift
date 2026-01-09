// ==================== TodoTool 应用入口 ====================
// 极简 macOS Todo 应用 - 零依赖、本地优先

import SwiftUI

@main
struct TodoToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 400, height: 600)
    }
}

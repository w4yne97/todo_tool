// ==================== 主界面视图 ====================
// 占位文件 - Phase 4 完善

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Todo Tool")
        }
        .padding()
        .frame(minWidth: 400, minHeight: 600)
    }
}

#Preview {
    ContentView()
}

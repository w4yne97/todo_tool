import SwiftUI

struct BatchActionsBar: View {
    let selectedCount: Int
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("已选 \(selectedCount) 项")
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 14)

            Button(action: onToggle) {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.plain)
            .help("切换完成状态 (⌘⏎)")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("删除选中 (⌘⌫)")

            Button(action: onCancel) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .help("取消选择")
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .animation(.easeInOut(duration: 0.2), value: selectedCount > 1)
    }
}

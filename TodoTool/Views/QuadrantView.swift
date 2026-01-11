// ==================== 四象限主视图 ====================
// 艾森豪威尔矩阵视图，以 2x2 网格展示四个象限的任务分布

import SwiftUI

/// 四象限视图
/// 以 2x2 网格布局展示任务按「重要性 × 紧急性」的分类
struct QuadrantView: View {
    /// 任务存储
    @ObservedObject var todoStore: TodoStore
    /// 返回列表视图回调
    var onDismiss: (() -> Void)?

    /// 网格布局配置
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            Divider()

            // 四象限网格
            quadrantGrid
                .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        HStack {
            Text("四象限视图")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // 返回按钮
            Button(action: { onDismiss?() }) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("列表视图")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 四象限网格
    private var quadrantGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Quadrant.gridOrder) { quadrant in
                QuadrantCard(
                    quadrant: quadrant,
                    todos: todoStore.todosByQuadrant[quadrant] ?? [],
                    onToggle: { id in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            todoStore.toggle(id: id)
                        }
                    },
                    onSelect: { _ in
                        // 选中逻辑（可扩展为打开详情）
                    }
                )
            }
        }
    }
}

// MARK: - 象限说明图例

/// 象限图例说明
struct QuadrantLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Quadrant.allCases, id: \.self) { quadrant in
                HStack(spacing: 4) {
                    Circle()
                        .fill(quadrant.color)
                        .frame(width: 8, height: 8)
                    Text(quadrant.shortName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("四象限视图") {
    QuadrantView(todoStore: TodoStore())
        .frame(width: 600, height: 500)
}

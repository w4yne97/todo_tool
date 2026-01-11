import SwiftUI
import AppKit

/// 四象限视图
struct QuadrantView: View {
    /// 任务存储
    @ObservedObject var todoStore: TodoStore
    /// 返回列表视图回调
    var onDismiss: (() -> Void)?

    /// 网格布局配置 - 增加间距
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    @State private var isAppearing = false

    var body: some View {
        ZStack {
            backgroundLayer
            
            VStack(spacing: 0) {
                headerView
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 32)

                // 使用 GeometryReader 计算卡片高度，使其铺满剩余空间
                GeometryReader { geometry in
                    let gridHeight = geometry.size.height
                    let cardHeight = (gridHeight - 20) / 2
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(Quadrant.gridOrder.enumerated()), id: \.element) { index, quadrant in
                            QuadrantCard(
                                quadrant: quadrant,
                                todos: todoStore.todosByQuadrant[quadrant] ?? [],
                                onToggle: { id in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        todoStore.toggle(id: id)
                                    }
                                },
                                onSelect: { _ in
                                    
                                }
                            )
                            .frame(height: max(200, cardHeight))
                            .opacity(isAppearing ? 1 : 0)
                            .offset(y: isAppearing ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1),
                                value: isAppearing
                            )
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAppearing = true
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            
            GeometryReader { proxy in
                Circle()
                    .fill(Color.blue.opacity(0.05))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: -100, y: -100)
                
                Circle()
                    .fill(Color.orange.opacity(0.05))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: proxy.size.width - 200, y: proxy.size.height - 200)
            }
        }
        .ignoresSafeArea()
    }

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("艾森豪威尔矩阵")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("按重要性与紧急性规划您的任务")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { onDismiss?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                    Text("列表视图")
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }



}

#Preview("四象限视图") {
    QuadrantView(todoStore: TodoStore())
        .frame(width: 800, height: 600)
}

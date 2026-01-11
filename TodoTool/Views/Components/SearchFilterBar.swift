import SwiftUI

struct SearchFilterBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    @Binding var priorityFilter: PriorityFilter
    @Binding var tagFilter: UUID?
    var tags: [Tag]
    var clearSearch: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("搜索任务…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onExitCommand {
                    searchText = ""
                    isSearchFocused = false
                }

            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            Divider()
                .frame(height: 16)

            priorityMenu

            if !tags.isEmpty {
                Divider()
                    .frame(height: 16)
                tagMenu
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(PriorityFilter.allCases) { filter in
                Button {
                    priorityFilter = filter
                } label: {
                    HStack(spacing: 8) {
                        if let priority = filter.priority {
                            Circle()
                                .fill(priorityTint(priority))
                                .frame(width: 10, height: 10)
                        }
                        Text(filter.displayName)
                        if priorityFilter == filter {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(priorityFilter.displayName)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(priorityFilter == .all ? Color.primary.opacity(0.05) : Color.accentColor.opacity(0.15))
            .cornerRadius(6)
        }
    }

    private var tagMenu: some View {
        Menu {
            Button("全部标签") {
                tagFilter = nil
            }
            .keyboardShortcut(.escape, modifiers: [])

            Divider()

            ForEach(tags) { tag in
                Button {
                    tagFilter = tag.id
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tag.color.color)
                            .frame(width: 10, height: 10)
                        Text(tag.name)
                        if tagFilter == tag.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(tagFilterLabel)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tagFilter == nil ? Color.primary.opacity(0.05) : Color.accentColor.opacity(0.15))
            .cornerRadius(6)
        }
    }

    private var tagFilterLabel: String {
        if let tagId = tagFilter, let tag = tags.first(where: { $0.id == tagId }) {
            return tag.name
        }
        return "全部标签"
    }

    private func priorityTint(_ priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .secondary
        }
    }
}

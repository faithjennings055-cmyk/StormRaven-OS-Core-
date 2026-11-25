import SwiftUI

/// Lists the tabs reported by the Edge-tabs provider, with the current tab
/// pinned first and remote focus/close commands per tab.
struct TabsView: View {
    @EnvironmentObject private var vm: KernelViewModel
    @State private var lastCommand: String?

    private var sortedTabs: [EdgeTab] {
        vm.tabs.sorted { a, b in
            if a.isCurrent != b.isCurrent { return a.isCurrent }
            return a.updatedUtc > b.updatedUtc
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Group {
                    if sortedTabs.isEmpty {
                        emptyState
                    } else {
                        tabList
                    }
                }
            }
            .navigationTitle("Edge tabs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await vm.refreshAll()
                            lastCommand = nil
                        }
                    } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
    }

    private var tabList: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let cmd = lastCommand {
                    Text(cmd)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(sortedTabs, id: \.id) { tab in
                    tabRow(tab)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func tabRow(_ tab: EdgeTab) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if tab.isCurrent {
                    Label("current", systemImage: "scope")
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().stroke(Theme.accent, lineWidth: 1))
                }
                if tab.isAudible {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accentWarm)
                }
                Spacer()
                Text(tab.updatedUtc.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.textDim)
            }
            Text(tab.title.isEmpty ? "(untitled)" : tab.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(tab.url)
                .font(.caption.monospaced())
                .foregroundStyle(Theme.textDim)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                Button {
                    Task {
                        let r = await vm.sendCommand("focus_tab", target: tab.id)
                        lastCommand = r.map { "focus_tab → \($0.status): \($0.detail)" }
                    }
                } label: {
                    Label("Focus", systemImage: "target")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surfaceAlt))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                Button {
                    Task {
                        let r = await vm.sendCommand("close_tab", target: tab.id)
                        lastCommand = r.map { "close_tab → \($0.status): \($0.detail)" }
                    }
                } label: {
                    Label("Close", systemImage: "xmark")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surfaceAlt))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(tab.isCurrent ? Theme.surfaceAlt : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(tab.isCurrent ? Theme.accent.opacity(0.55) : .clear, lineWidth: 1)
                )
        )
        .padding(.horizontal, 0)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textDim)
            Text("No tabs reported").foregroundStyle(Theme.textPrimary).font(.headline)
            Text("POST /tabs on the kernel feeds the Edge-tabs provider; the list updates live.")
                .font(.caption)
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

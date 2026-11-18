import SwiftUI

/// Live event console: everything arriving over the /ws stream plus command acks.
struct ConsoleView: View {
    @EnvironmentObject private var vm: KernelViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if vm.liveLog.isEmpty {
                            Text("waiting for events…")
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.textDim)
                                .padding()
                        }
                        ForEach(Array(vm.liveLog.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                }
            }
            .navigationTitle("Console")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.liveLog.removeAll()
                    } label: { Image(systemName: "trash") }
                }
            }
        }
    }
}

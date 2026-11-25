import SwiftUI

/// Root tab view: Status / Tabs / Decisions / Console / Link (settings).
struct RootView: View {
    @EnvironmentObject private var vm: KernelViewModel

    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Status", systemImage: "waveform.path.ecg") }
            TabsView()
                .tabItem { Label("Tabs", systemImage: "square.on.square") }
            DecisionsView()
                .tabItem { Label("Decisions", systemImage: "bolt.badge.clock") }
            ConsoleView()
                .tabItem { Label("Console", systemImage: "terminal") }
            LinkView()
                .tabItem { Label("Link", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .tint(Theme.accent)
        .task {
            await vm.refreshAll()
            vm.connectLive()
        }
    }
}

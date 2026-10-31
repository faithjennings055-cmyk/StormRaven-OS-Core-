import SwiftUI

@main
struct StormRavenApp: App {
    @StateObject private var vm = KernelViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .preferredColorScheme(.dark)
        }
    }
}

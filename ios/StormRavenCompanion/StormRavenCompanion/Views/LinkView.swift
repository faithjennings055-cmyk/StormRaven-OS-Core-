import SwiftUI

/// Connection settings: kernel host/port, TLS, connect/disconnect, and the
/// live route map for debugging.
struct LinkView: View {
    @EnvironmentObject private var vm: KernelViewModel
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var useTLS = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Form {
                    Section("Kernel (Bifrost gateway)") {
                        TextField("Host or IP", text: $host)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .foregroundStyle(Theme.textPrimary)
                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)
                            .foregroundStyle(Theme.textPrimary)
                        Toggle("TLS", isOn: $useTLS)
                            .tint(Theme.accent)
                    }
                    Section {
                        Button {
                            let p = Int(port) ?? 8787
                            var s = ConnectionSettings(host: host.trimmingCharacters(in: .whitespaces), port: p, useTLS: useTLS)
                            s.save()
                            vm.settings = s
                            saved = true
                            Task {
                                await vm.refreshAll()
                                vm.connectLive()
                            }
                        } label: {
                            Text(saved ? "Saved — reconnecting" : "Save & connect")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .tint(Theme.accent)
                        Button {
                            vm.disconnectLive()
                            vm.connection = .disconnected
                        } label: {
                            Text("Disconnect").frame(maxWidth: .infinity)
                        }
                        .tint(Theme.danger)
                    } footer: {
                        Text("The kernel listens on http://<windows-host>:8787. Same-network LAN access; loopback when running on the machine itself.")
                    }

                    Section("Route map") {
                        route("GET", "/health", "kernel status + counters")
                        route("GET", "/state", "last normalized state")
                        route("GET", "/tabs", "Edge-tabs provider output")
                        route("POST", "/tabs", "ingest tab signal → engine")
                        route("GET", "/decisions", "decision history")
                        route("POST", "/decisions/evaluate", "run engine on posted state")
                        route("POST", "/commands", "ping · get_state · get_tabs · evaluate · focus_tab · close_tab")
                        route("WS", "/ws", "live health/decision/signal stream")
                    }

                    Section("About") {
                        LabeledContent("Bridge", value: "bifrost · sr.bridge.mobile.v1")
                        LabeledContent("Envelope", value: "{ ok, data | error }")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Link")
            .onAppear {
                host = vm.settings.host
                port = String(vm.settings.port)
                useTLS = vm.settings.useTLS
            }
        }
    }

    private func route(_ method: String, _ path: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(method)
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(method == "GET" ? Theme.ok : Theme.accentWarm)
                    .frame(width: 44)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.surfaceAlt))
                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(note)
                .font(.caption2)
                .foregroundStyle(Theme.textDim)
                .padding(.leading, 52)
        }
        .padding(.vertical, 2)
    }
}

import SwiftUI

/// Kernel health at a glance: connection pill, uptime, counters, provider state,
/// normalized focus/system/network/power chips, and quick kernel commands.
struct StatusView: View {
    @EnvironmentObject private var vm: KernelViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        headerCard
                        countersCard
                        stateCard
                        providersCard
                        quickActionsCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("StormRaven OS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bird.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accent)
                .frame(width: 62, height: 62)
                .background(Circle().fill(Theme.surfaceAlt))
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.health?.kernel ?? "StormRaven OS")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("v\(vm.health?.version ?? "—")")
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.textDim)
                Text("bifrost \(vm.health?.bridgeVersion ?? "—")")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.textDim.opacity(0.7))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
    }

    private var countersCard: some View {
        HStack(spacing: 10) {
            counter("uptime", uptimeText)
            counter("signals", "\(vm.health?.signalCount ?? 0)")
            counter("tabs", "\(vm.health?.openTabs ?? vm.tabs.count)")
            counter("clients", "\(vm.health?.clients ?? 0)")
        }
    }

    private func counter(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
    }

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Normalized state")
                .font(.caption.uppercase())
                .foregroundStyle(Theme.textDim)
            chipRow("focus", vm.state?.focus.attention ?? "unknown")
            chipRow("activity", vm.state?.focus.foregroundActivity ?? "unknown")
            chipRow("cpu", vm.state?.system.cpuLoad ?? "unknown")
            chipRow("network", vm.state?.network.state ?? "unknown")
            chipRow("power", vm.state?.power.source ?? "unknown")
            if let t = vm.state?.timeUtc {
                Text("snapshot \(t.formatted(date: .omitted, time: .standard))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.textDim.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
    }

    private func chipRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Theme.textDim)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(valueColor(value))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.surfaceAlt))
        }
    }

    private var providersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Providers")
                .font(.caption.uppercase())
                .foregroundStyle(Theme.textDim)
            ForEach(vm.health?.providers ?? [], id: \.name) { p in
                HStack {
                    Image(systemName: "internet")
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.subheadline).foregroundStyle(Theme.textPrimary)
                        Text(p.schema).font(.caption2.monospaced()).foregroundStyle(Theme.textDim)
                    }
                    Spacer()
                    Text(p.state)
                        .font(.caption.monospaced())
                        .foregroundStyle(p.state == "streaming" ? Theme.ok : Theme.textDim)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceAlt))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kernel commands")
                .font(.caption.uppercase())
                .foregroundStyle(Theme.textDim)
            HStack(spacing: 10) {
                actionButton("Ping", "bolt.horizontal") { await vm.sendCommand("ping") }
                actionButton("Sync", "arrow.triangle.2.circlepath") { await vm.sendCommand("get_state") }
                actionButton("Evaluate", "brain.head.profile") { await vm.sendCommand("evaluate") }
            }
            Text("Commands run on the kernel's decision engine via POST /commands; results stream back live.")
                .font(.caption2)
                .foregroundStyle(Theme.textDim.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.body)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceAlt))
            .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }

    // helpers

    private var statusColor: Color {
        switch vm.connection {
        case .connected: return Theme.ok
        case .connecting: return Theme.accentWarm
        case .disconnected, .offline: return Theme.danger
        }
    }

    private var statusText: String {
        switch vm.connection {
        case .connected:      return "connected to bifrost"
        case .connecting:     return "connecting…"
        case .disconnected:   return "disconnected"
        case .offline(let r): return r
        }
    }

    private var uptimeText: String {
        let s = vm.health?.uptimeSec ?? 0
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)m\(s % 60)s"
    }

    private func valueColor(_ v: String) -> Color {
        switch v {
        case "focused", "online", "ac", "streaming": return Theme.ok
        case "idle", "low": return Theme.textPrimary
        case "high", "metered", "battery": return Theme.accentWarm
        default: return Theme.textDim
        }
    }
}

import SwiftUI

/// Decision-engine output: REST-loaded history plus live events pushed over /ws,
/// with trigger actions to run the engine on demand.
struct DecisionsView: View {
    @EnvironmentObject private var vm: KernelViewModel
    @State private var running = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        triggerCard
                        if vm.decisions.isEmpty {
                            emptyCard
                        } else {
                            ForEach(vm.decisions) { d in
                                decisionCard(d)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Decisions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await vm.refreshAll() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
    }

    private var triggerCard: some View {
        HStack(spacing: 10) {
            Button {
                running = true
                Task {
                    _ = await vm.sendCommand("evaluate")
                    running = false
                }
            } label: {
                HStack {
                    if running { ProgressView().tint(Theme.background) }
                    Label("Run engine", systemImage: "brain.head.profile")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
                .foregroundStyle(Theme.background)
            }
            .buttonStyle(.plain)
            .disabled(running)

            Button {
                Task { await vm.refreshAll() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func decisionCard(_ d: KernelDecision) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(d.severity.uppercased())
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(severityColor(d.severity))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().stroke(severityColor(d.severity), lineWidth: 1))
                Spacer()
                Text(d.time.formatted(date: .omitted, time: .standard))
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.textDim)
            }
            Text(d.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            if !d.ruleId.isEmpty {
                Text("rule \(d.ruleId) · confidence \(Int((d.confidence * 100).rounded()))%")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.accent.opacity(0.85))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.badge.clock")
                .font(.system(size: 38))
                .foregroundStyle(Theme.textDim)
            Text("No decisions yet").font(.headline).foregroundStyle(Theme.textPrimary)
            Text("Tap “Run engine” to evaluate the current normalized state, or wait for live signals.")
                .font(.caption)
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
    }

    private func severityColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "critical", "error": return Theme.danger
        case "warn", "warning":   return Theme.accentWarm
        default:                  return Theme.accent
        }
    }
}

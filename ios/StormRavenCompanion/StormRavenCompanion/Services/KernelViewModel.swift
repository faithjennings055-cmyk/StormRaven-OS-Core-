import Foundation
import Combine

/// Connection state exposed to the UI.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case offline(String)   // reason
}

/// The single source of truth for the app: talks to the kernel's Bifrost gateway
/// over REST (`/health`, `/tabs`, `/decisions`, `/commands`, ...) and keeps a
/// WebSocket open on `/ws` for live health ticks, decisions and command acks.
@MainActor
final class KernelViewModel: ObservableObject {
    // published UI state
    @Published var connection: ConnectionState = .disconnected
    @Published var health: KernelHealth?
    @Published var state: KernelState?
    @Published var tabs: [EdgeTab] = []
    @Published var decisions: [KernelDecision] = []
    @Published var liveLog: [String] = []
    @Published var settings: ConnectionSettings

    private let session: URLSession
    private var socketTask: URLSessionWebSocketTask?
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
    private var pingTimer: Timer?

    init(settings: ConnectionSettings = .load()) {
        self.settings = settings
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 6
        cfg.waitsForConnectivity = false
        session = URLSession(configuration: cfg)
    }

    // MARK: - REST

    private func fetch<T: Decodable>(_ path: String, as type: T.Type, method: String = "GET", body: Data? = nil) async throws -> T {
        var req = URLRequest(url: settings.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, http) = try await session.data(for: req)
        guard (200..<300).contains(http.statusCode) else {
            throw KernelError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let envelope = try decoder.decode(GatewayEnvelope<T>.self, from: data)
        guard envelope.ok, let payload = envelope.data else {
            throw KernelError.gateway(envelope.error?.message ?? "unknown gateway error")
        }
        return payload
    }

    func refreshAll() async {
        connection = .connecting
        do {
            let health = try await fetch("health", as: KernelHealth.self)
            self.health = health
            connection = .connected
            async let st: KernelState? = try? fetch("state", as: KernelState.self)
            async let tb: TabsEnvelope = fetch("tabs", as: TabsEnvelope.self)
            async let dc: DecisionsEnvelope = fetch("decisions", as: DecisionsEnvelope.self)
            let (s, t, d) = await (st, tb, dc)
            state = s
            tabs = t.tabs
            decisions = d.decisions
        } catch {
            connection = .offline(error.localizedDescription)
        }
    }

    // MARK: - Commands (decision-engine triggers etc.)

    func sendCommand(_ intent: String, target: String = "") async -> CommandResult? {
        let payload: [String: String] = ["intent": intent, "target": target]
        guard let body = try? JSONEncoder().encode(payload) else { return nil }
        do {
            let result = try await fetch("commands", as: CommandResult.self, method: "POST", body: body)
            appendLog("⌘ \(intent) → \(result.status)")
            _ = try await fetch("decisions", as: DecisionsEnvelope.self)  // refresh if the command ran the engine
            if let env = try? await session.data(for: URLRequest(url: settings.baseURL.appendingPathComponent("decisions"))) {
                if let e = try? decoder.decode(GatewayEnvelope<DecisionsEnvelope>.self, from: env.0), let data = e.data {
                    decisions = data.decisions
                }
            }
            return result
        } catch {
            appendLog("⌘ \(intent) failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - WebSocket live stream

    func connectLive() {
        disconnectLive()
        let task = session.webSocketTask(with: settings.webSocketURL)
        socketTask = task
        task.resume()
        receiveLoop(task)
        // keep NAT/sockets alive through idle periods
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.socketTask?.sendPing { _ in }
        }
    }

    func disconnectLive() {
        pingTimer?.invalidate(); pingTimer = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let err):
                Task { @MainActor in
                    if self.socketTask === task {
                        self.connection = .offline("live stream lost: \(err.localizedDescription)")
                        self.socketTask = nil
                    }
                }
            case .success(let msg):
                Task { @MainActor in
                    guard self.socketTask === task else { return }
                    self.connection = .connected
                    if case .string(let text) = msg {
                        self.handleLiveEvent(text)
                    }
                    self.receiveLoop(task)
                }
            }
        }
    }

    private func handleLiveEvent(_ text: String) {
        guard let evt = try? decoder.decode(KernelEvent.self, from: Data(text.utf8)) else { return }
        switch evt {
        case .hello:
            appendLog("● bifrost handshake ok")
            Task { await refreshAll() }
        case .healthTick:
            Task { await refreshHealthOnly() }
        case .decision(let live):
            decisions.insert(KernelDecision(live: live), at: 0)
            if decisions.count > 100 { decisions.removeLast(decisions.count - 100) }
            appendLog("⚡ \(live.summary)")
        case .signal(let provider, _):
            if let p = provider { appendLog("↯ signal \(p)") }
        case .commandAccepted(let intent, let status):
            appendLog("⌘ \(intent ?? "?") → \(status ?? "?")")
        case .pong, .other:
            break
        }
        objectWillChange.send()
    }

    private func refreshHealthOnly() async {
        if let h = try? await fetch("health", as: KernelHealth.self) {
            health = h
        }
    }

    private func appendLog(_ line: String) {
        let stamp = Date.now.formatted(date: .omitted, time: .standard)
        liveLog.insert("[\(stamp)] \(line)", at: 0)
        if liveLog.count > 200 { liveLog.removeLast(liveLog.count - 200) }
    }
}

enum KernelError: LocalizedError {
    case http(Int, String)
    case gateway(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "kernel HTTP \(code): \(body.prefix(140))"
        case .gateway(let msg):         return "bifrost: \(msg)"
        }
    }
}

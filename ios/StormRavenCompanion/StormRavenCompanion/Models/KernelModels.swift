import Foundation

// MARK: - Gateway envelope

/// Every Bifrost response is wrapped: { "ok": true, "data": {...} } or
/// { "ok": false, "error": { "code": ..., "message": ... } }.
struct GatewayEnvelope<Data: Decodable>: Decodable {
    let ok: Bool
    let data: Data?
    let error: GatewayError?
}

struct GatewayError: Decodable {
    let code: String
    let message: String
}

// MARK: - Health

struct KernelHealth: Decodable {
    let kernel: String
    let status: String
    let version: String
    let bridge: String
    let bridgeVersion: String
    let startedUtc: Date
    let uptimeSec: Int
    let signalCount: Int
    let openTabs: Int
    let pendingCommands: Int
    let clients: Int
    let lastActivityUtc: Date
    let providers: [ProviderStatus]
}

struct ProviderStatus: Decodable {
    let name: String
    let schema: String
    let state: String
}

// MARK: - Normalized state

struct KernelState: Decodable {
    let timeUtc: Date
    let focus: Focus
    let system: System
    let network: Network
    let power: Power

    struct Focus: Decodable {
        let attention: String
        let foregroundActivity: String
    }
    struct System: Decodable {
        let cpuLoad: String
        let memoryPressure: String
    }
    struct Network: Decodable {
        let state: String
    }
    struct Power: Decodable {
        let source: String
    }
}

// MARK: - Edge tabs

struct TabsEnvelope: Decodable {
    let provider: String
    let schema: String
    let count: Int
    let tabs: [EdgeTab]
}

struct EdgeTab: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let url: String
    let isCurrent: Bool
    let isAudible: Bool
    let updatedUtc: Date
}

// MARK: - Decisions

struct DecisionsEnvelope: Decodable {
    let count: Int
    let decisions: [KernelDecision]
}

struct KernelDecision: Decodable, Identifiable {
    let id: String
    let time: Date
    let severity: String
    let summary: String
    let ruleId: String
    let confidence: Double

    init(id: String, time: Date, severity: String, summary: String, ruleId: String, confidence: Double) {
        self.id = id; self.time = time; self.severity = severity
        self.summary = summary; self.ruleId = ruleId; self.confidence = confidence
    }

    /// Full REST shape: { v, type, id, time, severity, summary,
    ///                     evidence: [...], explainability: { ruleId, confidence } }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        time = try c.decode(Date.self, forKey: .time)
        severity = try c.decode(String.self, forKey: .severity)
        summary = try c.decode(String.self, forKey: .summary)
        let ex = try c.decodeIfPresent(Explainability.self, forKey: .explainability)
        ruleId = ex?.ruleId ?? ""
        confidence = ex?.confidence ?? 1.0
    }

    /// Live WebSocket shape: { id, time, severity, summary, ruleId }
    init(live: LiveDecisionEvent) {
        self.init(id: live.id, time: live.time, severity: live.severity,
                  summary: live.summary, ruleId: live.ruleId, confidence: 1.0)
    }

    private enum CodingKeys: String, CodingKey { case v, type, id, time, severity, summary, evidence, explainability }
}

struct EvidenceItem: Decodable {
    let signal: String
    let field: String
    let value: String
}

struct Explainability: Decodable {
    let ruleId: String
    let confidence: Double
}

// MARK: - Commands

struct CommandResult: Decodable {
    let intent: String
    let target: String
    let status: String   // "accepted" | "rejected"
    let detail: String
}

// MARK: - WebSocket events

/// Events pushed by the /ws stream: hello, pong, health.tick, decision,
/// signal, command.accepted.
enum KernelEvent: Decodable {
    case hello
    case pong
    case healthTick
    case decision(LiveDecisionEvent)
    case signal(provider: String?, schema: String?)
    case commandAccepted(intent: String?, status: String?)
    case other(type: String)

    private enum CodingKeys: String, CodingKey { case type, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "hello":        self = .hello
        case "pong":         self = .pong
        case "health.tick":  self = .healthTick
        case "decision":     self = .decision(try container.decode(LiveDecisionEvent.self, forKey: .data))
        case "signal":
            let d = try? container.nestedContainer(keyedBy: SignalKeys.self, forKey: .data)
            self = .signal(provider: try? d?.decodeIfPresent(String.self, forKey: .provider),
                           schema: try? d?.decodeIfPresent(String.self, forKey: .schema))
        case "command.accepted":
            let d = try? container.nestedContainer(keyedBy: CommandKeys.self, forKey: .data)
            self = .commandAccepted(intent: try? d?.decodeIfPresent(String.self, forKey: .intent),
                                    status: try? d?.decodeIfPresent(String.self, forKey: .status))
        default:             self = .other(type: type)
        }
    }

    private enum SignalKeys: String, CodingKey { case provider, schema }
    private enum CommandKeys: String, CodingKey { case intent, status }
}

/// Flattened decision event as broadcast on /ws.
struct LiveDecisionEvent: Decodable {
    let id: String
    let time: Date
    let severity: String
    let summary: String
    let ruleId: String?
}

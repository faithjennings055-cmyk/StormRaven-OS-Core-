// THE PANTHEON — 11-daemon modular intelligence registry.
// Per the Non-Destructive Mandate, all scanners/monitors default to "disabled"
// and require an explicit opt-in (config.ini) by the creator.

export type DaemonStatus = "online" | "idle" | "disabled" | "alert"

export type Daemon = {
  id: string
  name: string
  role: string
  port?: number
  description: string
  // Non-destructive default. Scanners start disabled.
  defaultStatus: DaemonStatus
  destructive: boolean
}

export const PANTHEON: Daemon[] = [
  {
    id: "odin",
    name: "Odin",
    role: "Allfather / Orchestrator",
    description: "Supervises the daemon hierarchy and arbitrates authority tokens.",
    defaultStatus: "online",
    destructive: false,
  },
  {
    id: "leviathan",
    name: "Leviathan",
    role: "Command Hierarchy",
    description: "Maps the Pantheon into the Leviathan start menu tree.",
    defaultStatus: "online",
    destructive: false,
  },
  {
    id: "heimdall",
    name: "Heimdall",
    role: "Gatekeeper / Sanitizer",
    description: "Heuristic regex inspection of all inbound commands (CWE-77).",
    defaultStatus: "online",
    destructive: false,
  },
  {
    id: "thor",
    name: "Thor",
    role: "Throughput / Rate Limiter",
    description: "Redis-backed DDoS and rate-limiting middleware hammer.",
    defaultStatus: "idle",
    destructive: false,
  },
  {
    id: "loki",
    name: "Loki",
    role: "Chaos / Fuzzer",
    description: "Fault-injection and fuzzing harness. Opt-in only.",
    defaultStatus: "disabled",
    destructive: true,
  },
  {
    id: "mjolnir",
    name: "Mjolnir",
    role: "Enforcement",
    description: "Applies quarantine verdicts and revokes compromised sessions.",
    defaultStatus: "idle",
    destructive: true,
  },
  {
    id: "fenrir",
    name: "Fenrir",
    role: "Active Scanner",
    description: "Aggressive port + surface scanner. Disabled by default.",
    defaultStatus: "disabled",
    destructive: true,
  },
  {
    id: "sleipnir",
    name: "Sleipnir",
    role: "Transport Mesh",
    description: "Eight-legged gRPC/IPC courier between host and edge.",
    defaultStatus: "online",
    destructive: false,
  },
  {
    id: "demogorgon",
    name: "Demogorgon",
    role: "TCP Tarpit Honeypot",
    port: 2222,
    description: "Multi-threaded tarpit on :2222 that ensnares intruders. Opt-in.",
    defaultStatus: "disabled",
    destructive: true,
  },
  {
    id: "jormungandr",
    name: "Jörmungandr",
    role: "Quarantine Gateway",
    description: "System isolation gateway that coils around flagged processes.",
    defaultStatus: "idle",
    destructive: true,
  },
  {
    id: "ginnungagap",
    name: "Ginnungagap",
    role: "Autonomous Sentinel",
    description: "Systemd-registered void watcher with heartbeat persistence.",
    defaultStatus: "online",
    destructive: false,
  },
]

export const STATUS_META: Record<
  DaemonStatus,
  { label: string; tone: "aurora" | "muted" | "alert" | "warn" }
> = {
  online: { label: "ONLINE", tone: "aurora" },
  idle: { label: "IDLE", tone: "muted" },
  disabled: { label: "DISABLED", tone: "warn" },
  alert: { label: "ALERT", tone: "alert" },
}

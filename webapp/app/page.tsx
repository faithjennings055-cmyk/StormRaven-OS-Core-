"use client"

import type React from "react"
import { useEffect, useMemo, useState } from "react"
import { useDispatch, useSelector } from "react-redux"
import {
  Activity,
  Cpu,
  FolderTree,
  Lock,
  Shield,
  ShieldAlert,
  Sparkles,
  Terminal,
  Wifi,
} from "lucide-react"
import RealmsView from "@/components/realms/RealmsView"
import { PANTHEON, STATUS_META, type DaemonStatus } from "@/lib/pantheon"
import { RUNIC_WHITELIST, heimdallrInspect, type RunicCommand } from "@/lib/heimdallr"
import { VFS, flattenFiles, type VfsNode } from "@/lib/vfs"
import {
  pushEvent,
  setBridge,
  setDaemonStatus,
  tick,
} from "@/lib/store/telemetry-slice"
import type { AppDispatch, RootState } from "@/components/store-provider"
import { useBifrost } from "@/hooks/use-bifrost"

const DEFAULT_GATEWAY = "https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"

export default function Page() {
  const dispatch = useDispatch<AppDispatch>()
  const telemetry = useSelector((s: RootState) => s.telemetry)
  const [activeTab, setActiveTab] = useState<"pantheon" | "heimdallr" | "vfs" | "mobile" | "realms">("pantheon")
  const [runeInput, setRuneInput] = useState("fehu /alfheim")
  const [selectedFile, setSelectedFile] = useState<VfsNode>(() => flattenFiles(VFS)[0])
  const [gatewayUrl, setGatewayUrl] = useState(DEFAULT_GATEWAY)
  const [kernelSummary, setKernelSummary] = useState<string>("Ubuntu 24.04 LTS (Noble Numbat) · Bifrost v1")

  // Connect to the real-time kernel bridge
  const kernelHost = gatewayUrl.replace("https://", "").replace("http://", "").split(":")[0]
  useBifrost(kernelHost)

  const files = useMemo(() => flattenFiles(VFS), [])

  useEffect(() => {
    let cancelled = false
    async function pollGateway() {
      try {
        const res = await fetch(`${gatewayUrl.replace(/\/+$/, "")}/status`, {
          headers: { Accept: "application/json" },
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const data = await res.json()
        if (cancelled) return
        const st = data.status || data.state || data
        setKernelSummary(
          `${st.distro || "StormRaven OS 24.04 LTS"} · uptime ${Math.floor((st.uptimeSec || 0) / 60)}m · ${st.openTabs ?? 0} tabs`,
        )
      } catch {
        if (!cancelled) dispatch(setBridge("degraded"))
      }
    }
    pollGateway()
    return () => {
      cancelled = true
    }
  }, [dispatch, gatewayUrl])

  // Sovereign Demo Pulse: Simulates a live kernel connection and data flow for preview
  useEffect(() => {
    dispatch(setBridge("connected"))
    
    const id = setInterval(() => {
      const now = Date.now()
      const updated = PANTHEON.map((d) => {
        const current = telemetry.daemons[d.id]
        const status = current?.status ?? d.defaultStatus
        const active = status === "online"
        return {
          id: d.id,
          status,
          cpu: active ? Math.min(95, Math.max(2, Math.round(4 + Math.random() * 14))) : 0,
          mem: active ? Math.min(92, Math.max(8, Math.round(12 + Math.random() * 10))) : 0,
          threads: d.id === "demogorgon" ? (active ? 8 : 0) : active ? 4 : 1,
          lastHeartbeat: now,
          events: current?.events ?? 0,
        }
      })
      dispatch(tick({ daemons: updated, threatLevel: telemetry.threatLevel }))

      if (Math.random() > 0.7) {
        const randomDaemon = PANTHEON[Math.floor(Math.random() * PANTHEON.length)]
        const severities: ("info" | "warn" | "alert")[] = ["info", "warn", "alert"]
        const sev = severities[Math.floor(Math.random() * severities.length)]
        const events = [
          "Heuristic scan completed: No threats found.",
          "Runic injection attempt blocked via Heimdallr.",
          "Sovereign authority token rotated.",
          "Telemetry spike detected in Muspelheim.",
          "Bifröst bridge latency within nominal range.",
          "Void signature verified for new process."
        ]
        dispatch(pushEvent({
          id: `demo-${Date.now()}`,
          daemon: randomDaemon.id,
          severity: sev,
          message: events[Math.floor(Math.random() * events.length)],
          ts: now,
        }))
      }
    }, 3000)
    return () => clearInterval(id)
  }, [dispatch, telemetry.daemons, telemetry.threatLevel])

  function handleRunicSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!runeInput.trim()) return
    const verdict = heimdallrInspect(runeInput)
    dispatch(
      pushEvent({
        id: `evt-${Date.now()}`,
        daemon: "heimdall",
        severity: verdict.severity,
        message: `[${ runeInput.trim() }] → ${verdict.reason}`,
        ts: Date.now(),
      }),
    )
    setRuneInput("")
  }

  function toggleDaemon(id: string, current: DaemonStatus) {
    const next: DaemonStatus = current === "online" ? "disabled" : "online"
    dispatch(setDaemonStatus({ id, status: next }))
    dispatch(
      pushEvent({
        id: `evt-${Date.now()}`,
        daemon: id,
        severity: next === "online" ? "info" : "warn",
        message: `Daemon ${id.toUpperCase()} transitioned to ${next.toUpperCase()}.`,
        ts: Date.now(),
      }),
    )
  }

  return (
    <main className="alfheim-void min-h-screen text-foreground flex flex-col">
      {/* Top Status Bar */}
      <header className="glass-strong border-b border-border px-4 py-3 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="size-9 rounded-lg bg-primary/15 border border-primary/40 flex items-center justify-center text-primary font-mono font-bold">
            ✦
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="font-mono text-sm sm:text-base font-bold tracking-wider text-foreground">
                ÁLFHEIMR · STORMRAVEN OS
              </h1>
              <span className="text-[11px] font-mono px-2 py-0.5 rounded-full bg-primary/15 text-primary border border-primary/30">
                v3.0 Noble
              </span>
            </div>
            <p className="text-xs text-muted-foreground font-mono">{kernelSummary}</p>
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <span className="inline-flex items-center gap-1.5 text-xs font-mono px-2.5 py-1 rounded-md bg-secondary border border-border">
            <Wifi className="size-3.5 text-primary" />
            Bifröst: {telemetry.bridge.toUpperCase()}
          </span>
          <a
            href={DEFAULT_GATEWAY}
            target="_blank"
            rel="noreferrer"
            className="text-xs font-mono px-3 py-1 rounded-md bg-primary text-primary-foreground font-semibold hover:opacity-90 transition"
          >
            Open Mobile & Kernel Gateway ↗
          </a>
        </div>
      </header>

      {/* Navigation Tabs */}
      <nav className="border-b border-border bg-card/60 px-4 flex gap-2 overflow-x-auto">
        {[
          { id: "pantheon", label: "Pantheon Daemons", icon: Cpu },
          { id: "heimdallr", label: "Heimdallr Runic Gate", icon: Terminal },
          { id: "vfs", label: "Yggdrasil VFS", icon: FolderTree },
          { id: "realms", label: "Nine Realms", icon: Sparkles },
          { id: "mobile", label: "Ubuntu 24.04 & Mobile", icon: Sparkles },
        ].map((t) => {
          const Icon = t.icon
          const active = activeTab === t.id
          return (
            <button
              key={t.id}
              type="button"
              onClick={() => setActiveTab(t.id as typeof activeTab)}
              className={`flex items-center gap-2 px-3.5 py-2.5 text-xs font-mono border-b-2 transition whitespace-nowrap ${
                active
                  ? "border-primary text-primary font-semibold"
                  : "border-transparent text-muted-foreground hover:text-foreground"
              }`}
            >
              <Icon className="size-3.5" />
              {t.label}
            </button>
          )
        })}
      </nav>

      {/* Main Content */}
      <div className="flex-1 p-4 sm:p-6 max-w-7xl w-full mx-auto grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          {activeTab === "pantheon" && (
            <section className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-sm font-mono uppercase tracking-wider text-primary">
                    The Pantheon Hierarchy (11 Autonomous Daemons)
                  </h2>
                  <p className="text-xs text-muted-foreground">
                    Non-destructive mandate active: offensive scanners default to disabled until explicitly opted in.
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {PANTHEON.map((d) => {
                  const st = telemetry.daemons[d.id]
                  const status = st?.status ?? d.defaultStatus
                  const meta = STATUS_META[status]
                  return (
                    <div
                      key={d.id}
                      className="glass rounded-xl p-4 border border-border flex flex-col justify-between gap-3"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <div className="flex items-center gap-2">
                            <h3 className="font-mono font-bold text-sm text-foreground">{d.name}</h3>
                            <span className="text-[11px] font-mono text-muted-foreground">· {d.role}</span>
                          </div>
                          <p className="text-xs text-muted-foreground mt-1">{d.description}</p>
                        </div>
                        <button
                          type="button"
                          onClick={() => toggleDaemon(d.id, status)}
                          className={`text-[10px] font-mono px-2 py-0.5 rounded border transition ${
                            status === "online"
                              ? "bg-primary/15 text-primary border-primary/40"
                              : status === "disabled"
                                ? "bg-muted text-muted-foreground border-border"
                                : "bg-accent/15 text-accent border-accent/40"
                          }`}
                        >
                          {meta.label}
                        </button>
                      </div>

                      <div className="flex items-center justify-between text-[11px] font-mono text-muted-foreground pt-2 border-t border-border/60">
                        <span>CPU {st?.cpu ?? 0}%</span>
                        <span>MEM {st?.mem ?? 0}%</span>
                        <span>THREADS {st?.threads ?? 1}</span>
                        <span>EVENTS {st?.events ?? 0}</span>
                      </div>
                    </div>
                  )
                })}
              </div>
            </section>
          )}

          {activeTab === "heimdallr" && (
            <section className="glass rounded-xl p-5 border border-border space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-sm font-mono uppercase tracking-wider text-primary flex items-center gap-2">
                    <Shield className="size-4" />
                    Heimdallr Command Sanitization Gateway (CWE-77)
                  </h2>
                  <p className="text-xs text-muted-foreground mt-0.5">
                    Inspects every command against heuristic injection signatures and the Runic whitelist.
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {(Object.keys(RUNIC_WHITELIST) as RunicCommand[]).map((rk) => {
                  const item = RUNIC_WHITELIST[rk]
                  return (
                    <button
                      key={rk}
                      type="button"
                      onClick={() => setRuneInput(`${rk} /alfheim`)}
                      className="text-left p-2.5 rounded-lg bg-secondary/70 hover:bg-secondary border border-border transition"
                    >
                      <div className="font-mono text-sm font-bold text-primary">
                        {item.glyph} {rk}
                      </div>
                      <div className="text-[11px] text-muted-foreground line-clamp-2 mt-0.5">{item.summary}</div>
                    </button>
                  )
                })}
              </div>

              <form onSubmit={handleRunicSubmit} className="flex gap-2">
                <input
                  type="text"
                  value={runeInput}
                  onChange={(e) => setRuneInput(e.target.value)}
                  placeholder="Enter runic command (e.g. fehu /alfheim or test injection rm -rf /)"
                  className="flex-1 rounded-lg bg-input border border-border px-3 py-2 text-xs font-mono text-foreground focus:outline-none focus:ring-1 focus:ring-primary"
                />
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-primary text-primary-foreground font-mono text-xs font-semibold hover:opacity-90 transition"
                >
                  Inspect & Dispatch
                </button>
              </form>
            </section>
          )}

          {activeTab === "vfs" && (
            <section className="glass rounded-xl p-5 border border-border grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="space-y-2 border-b md:border-b-0 md:border-r border-border pb-4 md:pb-0 md:pr-4">
                <h2 className="text-xs font-mono uppercase tracking-wider text-primary">Yggdrasil Realms</h2>
                {files.map((f) => (
                  <button
                    key={f.id}
                    type="button"
                    onClick={() => setSelectedFile(f)}
                    className={`w-full text-left px-3 py-2 rounded-lg text-xs font-mono transition ${
                      selectedFile.id === f.id
                        ? "bg-primary/15 text-primary border border-primary/30"
                        : "hover:bg-secondary text-muted-foreground"
                    }`}
                  >
                    <div>{f.name}</div>
                    <div className="text-[10px] opacity-70">{f.path}</div>
                  </button>
                ))}
              </div>
              <div className="md:col-span-2 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-mono text-primary">{selectedFile.path}</span>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-secondary text-muted-foreground">
                    Immutable Blueprint
                  </span>
                </div>
                <pre className="p-4 rounded-lg bg-black/60 border border-border text-xs font-mono text-foreground overflow-x-auto whitespace-pre-wrap leading-relaxed">
                  {selectedFile.content}
                </pre>
              </div>
            </section>
          )}

          {activeTab === "mobile" && (
            <section className="glass rounded-xl p-5 border border-border space-y-4">
              <h2 className="text-sm font-mono uppercase tracking-wider text-primary">
                StormRaven OS Ubuntu 24.04 LTS (Noble) & Mobile Companion
              </h2>
              <p className="text-xs text-muted-foreground">
                Connect directly to the live StormRaven Kernel & Odin Pantheon gateway on desktop or mobile.
              </p>
              <div className="space-y-2">
                <label className="text-xs font-mono text-muted-foreground block">Bifröst Cloud Gateway URL</label>
                <div className="flex gap-2">
                  <input
                    type="url"
                    value={gatewayUrl}
                    onChange={(e) => setGatewayUrl(e.target.value)}
                    className="flex-1 rounded-lg bg-input border border-border px-3 py-2 text-xs font-mono text-foreground"
                  />
                  <a
                    href={gatewayUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="px-4 py-2 rounded-lg bg-primary text-primary-foreground font-mono text-xs font-semibold"
                  >
                    Launch PWA ↗
                  </a>
                </div>
              </div>
              <div className="p-3.5 rounded-lg bg-black/60 border border-border space-y-1.5">
                <div className="text-xs font-mono text-primary">1-Command Android (Termux) / Ubuntu Mobile Setup</div>
                <code className="text-[11px] font-mono text-foreground block break-all">
                  curl -fsSL {DEFAULT_GATEWAY}/install-mobile.sh | bash
                </code>
              </div>
            </section>
          )}

          {activeTab === "realms" && <RealmsView />}
        </div>

        {/* Right Sidebar: Live Forensic Event Feed */}
        <aside className="glass rounded-xl p-4 border border-border flex flex-col h-fit space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-xs font-mono uppercase tracking-wider text-primary flex items-center gap-1.5">
              <Activity className="size-3.5" />
              Bifröst Event Ledger
            </h2>
            <span className="text-[10px] font-mono text-muted-foreground">{telemetry.feed.length} events</span>
          </div>

          <div className="space-y-2 max-h-[460px] overflow-y-auto pr-1">
            {telemetry.feed.length === 0 ? (
              <div className="text-xs font-mono text-muted-foreground py-8 text-center">
                No security verdicts recorded yet. Run a command in the Heimdallr Runic Gate or toggle a daemon.
              </div>
            ) : (
              telemetry.feed.map((ev) => (
                <div
                  key={ev.id}
                  className="p-2.5 rounded-lg bg-secondary/60 border border-border text-xs font-mono space-y-1"
                >
                  <div className="flex items-center justify-between">
                    <span
                      className={`text-[10px] uppercase px-1.5 py-0.5 rounded ${
                        ev.severity === "alert"
                          ? "bg-accent/20 text-accent"
                          : ev.severity === "warn"
                            ? "bg-yellow-500/20 text-yellow-300"
                            : "bg-primary/20 text-primary"
                      }`}
                    >
                      {ev.severity} · {ev.daemon}
                    </span>
                    <span className="text-[10px] text-muted-foreground">
                      {new Date(ev.ts).toLocaleTimeString()}
                    </span>
                  </div>
                  <div className="text-foreground break-words">{ev.message}</div>
                </div>
              ))
            )}
          </div>

          <div className="pt-2 border-t border-border flex items-center justify-between text-[11px] font-mono text-muted-foreground">
            <span className="inline-flex items-center gap-1">
              <Lock className="size-3 text-primary" /> Zero-Trust Enforced
            </span>
            <span className="inline-flex items-center gap-1">
              <ShieldAlert className="size-3 text-accent" /> CWE-77 Guard
            </span>
          </div>
        </aside>
      </div>
    </main>
  )
}

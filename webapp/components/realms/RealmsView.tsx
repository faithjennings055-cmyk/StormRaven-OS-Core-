"use client"

import React, { useState } from "react"
import { 
  Shield, Sparkles, Lock, Flame, 
  Database, Activity, Skull, Eye, Binary, HardDrive, Quote
} from "lucide-react"
import { useSelector } from "react-redux"
import { RootState } from "@/components/store-provider"
import { REALM_TOKENS, type RealmId } from "@/lib/realms"

export default function RealmsView() {
  const [activeRealm, setActiveRealm] = useState<RealmId>('asgard')
  const telemetry = useSelector((s: RootState) => s.telemetry)

  const realms = [
    { id: 'asgard' as const, icon: Shield },
    { id: 'vanaheim' as const, icon: Activity },
    { id: 'muspelheim' as const, icon: Flame },
    { id: 'jotunheim' as const, icon: HardDrive },
    { id: 'svartalfheim' as const, icon: Binary },
    { id: 'midgard' as const, icon: Eye },
    { id: 'alfheim' as const, icon: Sparkles },
    { id: 'niflheim' as const, icon: Database },
    { id: 'helheim' as const, icon: Lock },
    { id: 'valhalla' as const, icon: Skull },
  ]

  const current = REALM_TOKENS[activeRealm]

  return (
    <div className="flex h-full gap-6">
      {/* Realm Navigator */}
      <aside className="w-64 space-y-2 overflow-y-auto pr-2">
        {realms.map((r) => {
          const token = REALM_TOKENS[r.id]
          const isActive = activeRealm === r.id
          return (
            <button
              key={r.id}
              onClick={() => setActiveRealm(r.id)}
              style={isActive ? { borderColor: token.palette.border, backgroundColor: token.palette.surface, boxShadow: token.palette.glow } : undefined}
              className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-mono transition ${
                isActive 
                  ? `${token.palette.textClass} border` 
                  : "hover:bg-secondary text-muted-foreground border border-transparent"
              }`}
            >
              <span className="flex items-center gap-3">
                <r.icon className={`size-4 ${token.palette.textClass}`} />
                <span className="font-bold">{token.label}</span>
              </span>
              <span className="text-[10px] opacity-60">{token.transition.name}</span>
            </button>
          )
        })}
      </aside>

      {/* Realm Content with per-realm palette token, transition, lore & quote */}
      <div
        key={activeRealm}
        className={`flex-1 space-y-5 ${current.transition.enterClass} ${current.transition.reducedMotionClass}`}
      >
        <div className="flex items-center justify-between">
          <div>
            <h2 className={`text-lg font-mono font-bold flex items-center gap-2 ${current.palette.textClass}`}>
              {current.label}
            </h2>
            <p className="text-xs text-muted-foreground font-mono">
              {current.domain} · <span className="opacity-75">{current.motif}</span>
            </p>
          </div>
          <div className={`text-[10px] font-mono px-2.5 py-1 rounded border ${current.palette.badgeClass}`}>
            REALM_{activeRealm.toUpperCase()}
          </div>
        </div>

        {/* Realm Lore & Norse-Tech Quote Banner */}
        <div
          style={{ borderColor: current.palette.border, backgroundColor: current.palette.surface, boxShadow: current.palette.glow }}
          className="rounded-xl p-4 border space-y-2"
        >
          <p className="text-xs font-mono text-foreground/90 leading-relaxed">
            {current.lore}
          </p>
          <div className={`flex items-center gap-2 text-[11px] font-mono italic ${current.palette.textClass}`}>
            <Quote className="size-3.5 shrink-0 opacity-80" />
            <span>"{current.quote}"</span>
          </div>
        </div>

        <div className={`glass rounded-xl p-6 border min-h-[340px] space-y-4 ${current.palette.panelClass}`}>
          {activeRealm === 'asgard' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 rounded-lg bg-black/40 border border-border space-y-2">
                  <h3 className={`text-xs font-mono uppercase ${current.palette.textClass}`}>Persona Matrix</h3>
                  <div className="space-y-1">
                    <div className="flex justify-between text-[11px] font-mono">
                      <span>Odin (Void)</span> <span className={current.palette.textClass}>ACTIVE</span>
                    </div>
                    <div className="flex justify-between text-[11px] font-mono">
                      <span>Thor (Sovereign)</span> <span className="text-muted-foreground">READY</span>
                    </div>
                    <div className="flex justify-between text-[11px] font-mono">
                      <span>Heimdall (Gatekeeper)</span> <span className="text-emerald-400">ENFORCING</span>
                    </div>
                  </div>
                </div>
                <div className="p-4 rounded-lg bg-black/40 border border-border space-y-2">
                  <h3 className={`text-xs font-mono uppercase ${current.palette.textClass}`}>Sovereign Command</h3>
                  <div className="flex gap-2">
                    <input 
                      type="text" 
                      placeholder="stormraven realms --verify" 
                      className="flex-1 bg-input border border-border rounded px-2 py-1 text-[11px] font-mono"
                    />
                    <button className="px-2 py-1 bg-primary text-primary-foreground text-[11px] font-bold rounded">
                      EXEC
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeRealm === 'vanaheim' && (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {[
                { label: 'CPU Saturation', val: `${telemetry?.cpu ?? 14}%` },
                { label: 'RAM Pressure', val: `${telemetry?.ram ?? 38}%` },
                { label: 'Matrix Stability', val: '99.98%' },
              ].map(metric => (
                <div key={metric.label} className="p-4 rounded-lg bg-black/40 border border-border text-center">
                  <div className="text-[10px] font-mono text-muted-foreground uppercase">{metric.label}</div>
                  <div className={`text-xl font-mono font-bold ${current.palette.textClass}`}>{metric.val}</div>
                </div>
              ))}
            </div>
          )}

          {activeRealm === 'muspelheim' && (
            <div className="space-y-4">
              <h3 className={`text-xs font-mono uppercase ${current.palette.textClass}`}>Entropy Injectors</h3>
              <div className="grid grid-cols-2 gap-2">
                {['Slight Latency (25ms)', 'Packet Loss (5%)', 'Daemon Stress Probe', 'Rate-Limit Surge'].map(fault => (
                  <button key={fault} className="p-3 text-left rounded-lg bg-rose-500/10 border border-rose-500/30 hover:bg-rose-500/20 transition text-xs font-mono text-rose-300">
                    Inject {fault}
                  </button>
                ))}
              </div>
            </div>
          )}

          {activeRealm === 'jotunheim' && (
            <div className="space-y-3 font-mono text-xs">
              <h3 className={`uppercase ${current.palette.textClass}`}>Immutable Forensic Ledger (SHA-256)</h3>
              <div className="p-3 rounded-lg bg-black/50 border border-border space-y-1.5 text-[11px]">
                <div className="flex justify-between"><span>/var/log/audit/audit.log</span><span className="text-sky-300">VERIFIED · READ-ONLY</span></div>
                <div className="flex justify-between"><span>dc3dd + sleuthkit + yara</span><span className="text-emerald-400">ARMED</span></div>
                <div className="flex justify-between"><span>Chain-of-Custody Manifest</span><span className="text-sky-300">SHA-256 LOCKED</span></div>
              </div>
            </div>
          )}

          {activeRealm === 'svartalfheim' && (
            <div className="space-y-3 font-mono text-xs">
              <h3 className={`uppercase ${current.palette.textClass}`}>Ymir Binary & Allocator Forge</h3>
              <div className="p-3 rounded-lg bg-black/50 border border-border space-y-1.5 text-[11px]">
                <div className="flex justify-between"><span>StormRaven.Kernel (source-built)</span><span className="text-purple-300">ELF64 · VERIFIED</span></div>
                <div className="flex justify-between"><span>Ymir Buddy/SLAB Allocator</span><span className="text-emerald-400">DETERMINISTIC</span></div>
                <div className="flex justify-between"><span>Pre-compiled chroot blobs</span><span className="text-purple-300">PURGED (#12)</span></div>
              </div>
            </div>
          )}

          {activeRealm === 'midgard' && (
            <div className="space-y-3 font-mono text-xs">
              <h3 className={`uppercase ${current.palette.textClass}`}>Bifrost Perimeter & WireGuard Mesh</h3>
              <div className="p-3 rounded-lg bg-black/50 border border-border space-y-1.5 text-[11px]">
                <div className="flex justify-between"><span>Bifrost Gateway (:8787)</span><span className="text-cyan-300">BEARER + WS TOKEN GATED</span></div>
                <div className="flex justify-between"><span>WireGuard Kill-Switch (wg0)</span><span className="text-emerald-400">STORMRAVEN_KILLSWITCH READY</span></div>
                <div className="flex justify-between"><span>UFW Firewall Baseline</span><span className="text-cyan-300">DEFAULT DENY INCOMING</span></div>
              </div>
            </div>
          )}

          {activeRealm === 'alfheim' && (
            <div className="space-y-3 font-mono text-xs">
              <h3 className={`uppercase ${current.palette.textClass}`}>Ethereal Void Shell Tokens</h3>
              <div className="grid grid-cols-3 gap-3 text-[11px]">
                <div className="p-3 rounded bg-black/50 border border-border">Void Base: <span className="text-fuchsia-300">#07030a</span></div>
                <div className="p-3 rounded bg-black/50 border border-border">Icy Cyan: <span className="text-cyan-300">#06b6d4</span></div>
                <div className="p-3 rounded bg-black/50 border border-border">Magenta: <span className="text-purple-300">#a855f7</span></div>
              </div>
            </div>
          )}

          {activeRealm === 'niflheim' && (
            <div className="space-y-3 font-mono text-xs">
              <h3 className={`uppercase ${current.palette.textClass}`}>Niflheim Snapshot & Recovery Vault</h3>
              <div className="p-3 rounded-lg bg-black/50 border border-border space-y-1.5 text-[11px]">
                <div className="flex justify-between"><span>Timeshift + NiflheimSnapshotManager</span><span className="text-indigo-300">ACTIVE</span></div>
                <div className="flex justify-between"><span>KVM/QEMU VM Pool (/var/lib/libvirt/images)</span><span className="text-emerald-400">READY</span></div>
              </div>
            </div>
          )}

          {activeRealm === 'helheim' && (
            <div className="space-y-3 font-mono text-xs">
              <h3 className={`uppercase ${current.palette.textClass}`}>Helheim Isolation Vault & Quarantine</h3>
              <div className="p-3 rounded-lg bg-black/50 border border-border space-y-1.5 text-[11px]">
                <div className="flex justify-between"><span>HelheimIsolationVault</span><span className="text-slate-300">ZERO-EGRESS ARMED</span></div>
                <div className="flex justify-between"><span>Jörmungandr Process Containment</span><span className="text-emerald-400">STANDBY</span></div>
              </div>
            </div>
          )}

          {activeRealm === 'valhalla' && (
            <div className="space-y-2 font-mono text-[11px]">
              <div className={`uppercase text-xs mb-2 ${current.palette.textClass}`}>The Obituaries</div>
              <div className="p-3 rounded bg-black/60 border border-border text-muted-foreground italic">
                "The Void is silent. No daemons have fallen this epoch."
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

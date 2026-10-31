"use client"

import React, { useState } from "react"
import { 
  Shield, Zap, Sparkles, Lock, Wifi, Flame, 
  Database, Activity, Skull, Eye, Binary, HardDrive 
} from "lucide-react"
import { useDispatch, useSelector } from "react-redux"
import { RootState } from "@/components/store-provider"

type RealmId = 'asgard' | 'vanaheim' | 'muspelheim' | 'jotunheim' | 'svartalfheim' | 'midgard' | 'alfheim' | 'niflheim' | 'helheim' | 'valhalla'

export default function RealmsView() {
  const [activeRealm, setActiveRealm] = useState<RealmId>('asgard')
  const telemetry = useSelector((s: RootState) => s.telemetry)

  const realms = [
    { id: 'asgard', label: 'Asgard', icon: Shield, color: 'text-yellow-400', desc: 'Persona Matrix & Sovereign Command' },
    { id: 'vanaheim', label: 'Vanaheim', icon: Activity, color: 'text-green-400', desc: 'Vitality Monitor & System Health' },
    { id: 'muspelheim', label: 'Muspelheim', icon: Flame, color: 'text-red-500', desc: 'Chaos Engine & Fault Injection' },
    { id: 'jotunheim', label: 'Jotunheim', icon: HardDrive, color: 'text-blue-400', desc: 'Deep Archive & Forensic Logs' },
    { id: 'svartalfheim', label: 'Svartalfheim', icon: Binary, color: 'text-purple-400', desc: 'Binary Manager & Void Signatures' },
    { id: 'midgard', label: 'Midgard', icon: Eye, color: 'text-cyan-400', desc: 'Operational Layer & Request Routing' },
    { id: 'alfheim', label: 'Alfheim', icon: Sparkles, color: 'text-pink-400', desc: 'Ethereal Edge UI (Current Shell)' },
    { id: 'niflheim', label: 'Niflheim', icon: Database, color: 'text-indigo-400', desc: 'State Snapshotting & Recovery' },
    { id: 'helheim', label: 'Helheim', icon: Lock, color: 'text-gray-500', desc: 'Isolation Vault & Quarantine' },
    { id: 'valhalla', label: 'Valhalla', icon: Skull, color: 'text-orange-400', desc: 'The Hall of Fallen Daemons' },
  ] as const

  return (
    <div className="flex h-full gap-6">
      {/* Realm Navigator */}
      <aside className="w-64 space-y-2 overflow-y-auto pr-2">
        {realms.map((r) => (
          <button
            key={r.id}
            onClick={() => setActiveRealm(r.id)}
            className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-xs font-mono transition ${
              activeRealm === r.id 
                ? "bg-primary/20 text-primary border border-primary/40" 
                : "hover:bg-secondary text-muted-foreground border border-transparent"
            }`}
          >
            <r.icon className={`size-4 ${r.color}`} />
            <span className="font-bold">{r.label}</span>
          </button>
        ))}
      </aside>

      {/* Realm Content */}
      <div className="flex-1 space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-mono font-bold text-foreground flex items-center gap-2">
              {realms.find(r => r.id === activeRealm)?.label}
            </h2>
            <p className="text-xs text-muted-foreground font-mono">
              {realms.find(r => r.id === activeRealm)?.desc}
            </p>
          </div>
          <div className="text-[10px] font-mono px-2 py-1 rounded bg-primary/10 text-primary border border-primary/30">
            REALM_{activeRealm.toUpperCase()}
          </div>
        </div>

        <div className="glass rounded-xl p-6 border border-border min-h-[400px] space-y-4">
          {activeRealm === 'asgard' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 rounded-lg bg-black/40 border border-border space-y-2">
                  <h3 className="text-xs font-mono text-primary uppercase">Persona Matrix</h3>
                  <div className="space-y-1">
                    <div className="flex justify-between text-[11px] font-mono">
                      <span>Odin (Void)</span> <span className="text-primary">ACTIVE</span>
                    </div>
                    <div className="flex justify-between text-[11px] font-mono">
                      <span>Thor (Sovereign)</span> <span className="text-muted-foreground">IDLE</span>
                    </div>
                  </div>
                </div>
                <div className="p-4 rounded-lg bg-black/40 border border-border space-y-2">
                  <h3 className="text-xs font-mono text-primary uppercase">Sovereign Command</h3>
                  <div className="flex gap-2">
                    <input 
                      type="text" 
                      placeholder="reboot-matrix" 
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
              {['CPU Saturation', 'Bus Latency', 'Matrix Stability'].map(metric => (
                <div key={metric} className="p-4 rounded-lg bg-black/40 border border-border text-center">
                  <div className="text-[10px] font-mono text-muted-foreground uppercase">{metric}</div>
                  <div className="text-xl font-mono font-bold text-primary">--</div>
                </div>
              ))}
            </div>
          )}

          {activeRealm === 'muspelheim' && (
            <div className="space-y-4">
              <h3 className="text-xs font-mono text-red-500 uppercase">Entropy Injectors</h3>
              <div className="grid grid-cols-2 gap-2">
                {['Slight Latency', 'Packet Loss', 'Daemon Panic', 'Void Collapse'].map(fault => (
                  <button key={fault} className="p-3 text-left rounded-lg bg-red-500/10 border border-red-500/30 hover:bg-red-500/20 transition text-xs font-mono text-red-400">
                    Inject {fault}
                  </button>
                ))}
              </div>
            </div>
          )}

          {activeRealm === 'valhalla' && (
            <div className="space-y-2 font-mono text-[11px]">
              <div className="text-primary uppercase text-xs mb-2">The Obituaries</div>
              <div className="p-3 rounded bg-black/60 border border-border text-muted-foreground italic">
                "The Void is silent. No daemons have fallen this epoch."
              </div>
            </div>
          )}

          {/* Generic fallback for other realms */}
          {!['asgard', 'vanaheim', 'muspelheim', 'valhalla'].includes(activeRealm) && (
            <div className="flex flex-col items-center justify-center h-full text-center space-y-2 opacity-50">
              <div className="size-12 rounded-full bg-muted flex items-center justify-center">
                <Lock className="size-6 text-muted-foreground" />
              </div>
              <p className="text-xs font-mono text-muted-foreground">
                Realm {activeRealm} is currently in stasis. <br/>
                Sovereign authorization required for manifestation.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

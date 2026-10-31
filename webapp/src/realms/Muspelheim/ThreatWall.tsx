"use client"

import React from "react"
import { Flame, Shield, AlertTriangle } from "lucide-react"

interface ThreatItem {
  id: string
  source: string
  severity: "CRITICAL" | "HIGH" | "MODERATE"
  status: "ACTIVE" | "CONTAINED" | "MONITORING"
  impact: string
  entropy: string
}

const ThreatWall: React.FC = () => {
  const threats: ThreatItem[] = [
    { id: "T-01", source: "Void-Siphon", severity: "CRITICAL", status: "ACTIVE", impact: "Kernel Instability", entropy: "89%" },
    { id: "T-02", source: "Fenrir-Burst", severity: "HIGH", status: "CONTAINED", impact: "Bus Latency", entropy: "42%" },
    { id: "T-03", source: "Surtur-Singe", severity: "MODERATE", status: "MONITORING", impact: "Thermal Throttle", entropy: "15%" },
  ]

  const getSeverityBadge = (sev: ThreatItem["severity"]) => {
    switch (sev) {
      case "CRITICAL":
        return "bg-red-500/20 text-red-400 border-red-500/40"
      case "HIGH":
        return "bg-orange-500/20 text-orange-400 border-orange-500/40"
      case "MODERATE":
        return "bg-yellow-500/20 text-yellow-300 border-yellow-500/40"
    }
  }

  return (
    <div className="p-6 bg-[#07030a] min-h-screen text-slate-200 font-mono">
      <div className="rounded-xl bg-[#0c0713] border border-red-500/40 p-5 space-y-4">
        <div className="flex items-center gap-2 text-red-400 font-bold text-base">
          <Flame className="size-5" />
          <h3>Muspelheim Threat-Wall</h3>
        </div>
        <p className="text-xs text-slate-400">
          Real-time entropy monitoring of the Hybrid Microkernel Matrix.
        </p>

        <div className="overflow-x-auto border border-border rounded-lg">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-border bg-secondary/60 text-muted-foreground uppercase text-[10px]">
                <th className="py-2 px-3">ID</th>
                <th className="py-2 px-3">Source</th>
                <th className="py-2 px-3">Severity</th>
                <th className="py-2 px-3">Status</th>
                <th className="py-2 px-3">Impact</th>
                <th className="py-2 px-3">Entropy</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60">
              {threats.map((t) => (
                <tr key={t.id} className="hover:bg-secondary/40 transition">
                  <td className="py-2 px-3 font-bold text-primary">{t.id}</td>
                  <td className="py-2 px-3">{t.source}</td>
                  <td className="py-2 px-3">
                    <span className={`px-2 py-0.5 rounded border text-[10px] ${getSeverityBadge(t.severity)}`}>
                      {t.severity}
                    </span>
                  </td>
                  <td className="py-2 px-3">
                    <span className="inline-flex items-center gap-1.5">
                      {t.status === "ACTIVE" ? (
                        <AlertTriangle className="size-3.5 text-red-400" />
                      ) : (
                        <Shield className="size-3.5 text-emerald-400" />
                      )}
                      {t.status}
                    </span>
                  </td>
                  <td className="py-2 px-3 text-muted-foreground">{t.impact}</td>
                  <td className="py-2 px-3 text-accent font-semibold">{t.entropy}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

export default ThreatWall

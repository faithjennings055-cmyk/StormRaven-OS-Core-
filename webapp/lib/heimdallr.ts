// HEIMDALLR — command sanitization gateway.
// All input is routed through heuristic regex analysis before it is allowed to
// reach the (mocked) execution layer, guarding against command injection
// (CWE-77). Execution is locked to a whitelist of "Runic" commands.

export type RunicCommand = "fehu" | "algiz" | "isa" | "raido"

export const RUNIC_WHITELIST: Record<
  RunicCommand,
  { glyph: string; summary: string }
> = {
  fehu: { glyph: "ᚠ", summary: "Enumerate wealth — list VFS ledger resources." },
  algiz: { glyph: "ᛉ", summary: "Raise wards — run a defensive posture check." },
  isa: { glyph: "ᛁ", summary: "Freeze — quarantine a flagged process (Jörmungandr)." },
  raido: { glyph: "ᚱ", summary: "Journey — trace a route through the daemon mesh." },
}

// Heuristic injection signatures (CWE-77 / CWE-78).
const INJECTION_PATTERNS: { re: RegExp; label: string }[] = [
  { re: /[;&|`]|\$\(|\|\|/, label: "shell metacharacter / chaining" },
  { re: /\b(rm|dd|mkfs|shutdown|reboot|kill|chmod|chown)\b/i, label: "destructive binary" },
  { re: /(\.\.\/|\/etc\/|\/proc\/|\/dev\/)/, label: "path traversal / sensitive path" },
  { re: /<script|javascript:|onerror=/i, label: "script injection" },
  { re: /\b(curl|wget|nc|ncat|bash|sh|python|perl)\b/i, label: "remote fetch / interpreter" },
  { re: /%[0-9a-f]{2}|\\x[0-9a-f]{2}/i, label: "encoded payload" },
]

export type Verdict = {
  ok: boolean
  command?: RunicCommand
  args: string
  severity: "info" | "warn" | "alert"
  reason: string
  threats: string[]
}

export function heimdallrInspect(raw: string): Verdict {
  const input = raw.trim()
  const threats: string[] = []

  for (const { re, label } of INJECTION_PATTERNS) {
    if (re.test(input)) threats.push(label)
  }

  const [head, ...rest] = input.split(/\s+/)
  const command = head?.toLowerCase() as RunicCommand
  const args = rest.join(" ")

  if (threats.length > 0) {
    return {
      ok: false,
      args,
      severity: "alert",
      reason: `Intercepted — heuristic analysis flagged: ${threats.join(", ")}.`,
      threats,
    }
  }

  if (!command || !(command in RUNIC_WHITELIST)) {
    return {
      ok: false,
      args,
      severity: "warn",
      reason: `Rune "${head ?? ""}" is not in the sanctioned whitelist (fehu, algiz, isa, raido).`,
      threats,
    }
  }

  return {
    ok: true,
    command,
    args,
    severity: "info",
    reason: `Rune ${RUNIC_WHITELIST[command].glyph} ${command} cleared for execution.`,
    threats,
  }
}

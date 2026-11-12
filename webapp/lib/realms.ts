// THE NINE REALMS — Canonical palette tokens, motion transitions, lore, and Norse-tech quotes.
// Owned by Luci (visual identity, palettes, lore + quote voice) & Sunray (transitions/motion).

export type RealmId =
  | "asgard"
  | "vanaheim"
  | "muspelheim"
  | "jotunheim"
  | "svartalfheim"
  | "midgard"
  | "alfheim"
  | "niflheim"
  | "helheim"
  | "valhalla"

export type RealmToken = {
  id: RealmId
  label: string
  domain: string
  // Named design tokens (bound across UI & PWA, never scattered hardcoded hex)
  palette: {
    primary: string
    accent: string
    surface: string
    border: string
    glow: string
    textClass: string
    badgeClass: string
    panelClass: string
  }
  motif: string
  transition: {
    name: string
    enterClass: string
    reducedMotionClass: string
  }
  lore: string
  quote: string
}

export const REALM_TOKENS: Record<RealmId, RealmToken> = {
  asgard: {
    id: "asgard",
    label: "Asgard",
    domain: "Persona Matrix & Sovereign Command",
    palette: {
      primary: "#facc15",
      accent: "#06b6d4",
      surface: "rgba(250, 204, 21, 0.06)",
      border: "rgba(250, 204, 21, 0.32)",
      glow: "0 0 28px rgba(250, 204, 21, 0.14)",
      textClass: "text-amber-300",
      badgeClass: "bg-amber-400/10 text-amber-300 border-amber-400/30",
      panelClass: "border-amber-400/30 bg-gradient-to-br from-amber-500/5 via-[#07030a] to-cyan-500/5",
    },
    motif: "Sovereign gold lattice over deep void (#07030a)",
    transition: {
      name: "bifrost-ascend",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in zoom-in-95",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "High seat of the Pantheon where Odin arbitrates authority tokens and binds every daemon to the Sovereign will. No instruction crosses the bus without Hlidskjalf's signature.",
    quote: "One eye on the kernel, one eye on the void. Nothing executes unseen.",
  },
  vanaheim: {
    id: "vanaheim",
    label: "Vanaheim",
    domain: "Vitality Monitor & System Health",
    palette: {
      primary: "#34d399",
      accent: "#06b6d4",
      surface: "rgba(52, 211, 153, 0.06)",
      border: "rgba(52, 211, 153, 0.32)",
      glow: "0 0 28px rgba(52, 211, 153, 0.14)",
      textClass: "text-emerald-300",
      badgeClass: "bg-emerald-400/10 text-emerald-300 border-emerald-400/30",
      panelClass: "border-emerald-400/30 bg-gradient-to-br from-emerald-500/5 via-[#07030a] to-teal-500/5",
    },
    motif: "Bioluminescent pulse grid with living telemetry waveforms",
    transition: {
      name: "pulse-bloom",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in slide-in-from-bottom-2",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "The living canopy of the machine. Freya and Idunn measure every heartbeat of CPU saturation, memory pressure, and bus latency to keep the host immortal.",
    quote: "A healthy kernel breathes in microseconds; a dying one gasps in swap.",
  },
  muspelheim: {
    id: "muspelheim",
    label: "Muspelheim",
    domain: "Chaos Engine & Fault Injection",
    palette: {
      primary: "#f43f5e",
      accent: "#f97316",
      surface: "rgba(244, 63, 94, 0.07)",
      border: "rgba(244, 63, 94, 0.36)",
      glow: "0 0 32px rgba(244, 63, 94, 0.18)",
      textClass: "text-rose-400",
      badgeClass: "bg-rose-500/10 text-rose-300 border-rose-500/35",
      panelClass: "border-rose-500/35 bg-gradient-to-br from-rose-500/10 via-[#07030a] to-orange-500/5",
    },
    motif: "Ember-ash fracture lines over charred obsidian",
    transition: {
      name: "fire-ash-dissolve",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in slide-in-from-top-2",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "Crucible of controlled entropy. Loki and Surtr hurl packet loss, latency spikes, and fault storms against the defensive wall so weak assumptions burn before production.",
    quote: "If your service cannot survive the fire we set, it will never survive the fire waiting outside.",
  },
  jotunheim: {
    id: "jotunheim",
    label: "Jotunheim",
    domain: "Deep Archive & Forensic Logs",
    palette: {
      primary: "#38bdf8",
      accent: "#818cf8",
      surface: "rgba(56, 189, 248, 0.06)",
      border: "rgba(56, 189, 248, 0.32)",
      glow: "0 0 28px rgba(56, 189, 248, 0.14)",
      textClass: "text-sky-300",
      badgeClass: "bg-sky-400/10 text-sky-300 border-sky-400/30",
      panelClass: "border-sky-400/30 bg-gradient-to-br from-sky-500/5 via-[#07030a] to-indigo-500/5",
    },
    motif: "Monolithic basalt strata with immutable SHA-256 ledger lines",
    transition: {
      name: "monolith-shift",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in slide-in-from-left-2",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "Ancient stone vaults where Saga carves every syscall, audit trail, and chain-of-custody hash into read-only granite. Time passes; the ledger remains.",
    quote: "Memory lies when convenient. A signed SHA-256 manifest does not.",
  },
  svartalfheim: {
    id: "svartalfheim",
    label: "Svartalfheim",
    domain: "Binary Manager & Void Signatures",
    palette: {
      primary: "#a855f7",
      accent: "#06b6d4",
      surface: "rgba(168, 85, 247, 0.07)",
      border: "rgba(168, 85, 247, 0.36)",
      glow: "0 0 28px rgba(168, 85, 247, 0.16)",
      textClass: "text-purple-300",
      badgeClass: "bg-purple-500/10 text-purple-300 border-purple-500/35",
      panelClass: "border-purple-500/35 bg-gradient-to-br from-purple-500/10 via-[#07030a] to-fuchsia-500/5",
    },
    motif: "Subterranean forge circuitry with hex-dump scanlines",
    transition: {
      name: "forge-glitch",
      enterClass: "transition-all duration-200 ease-in-out animate-in fade-in zoom-in-98",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "The dark forge beneath the roots where Ymir's Rust allocators and ELF binaries are hammered, stripped, and verified against known-good signatures before execution.",
    quote: "Trust no binary you did not forge from source and measure in the dark.",
  },
  midgard: {
    id: "midgard",
    label: "Midgard",
    domain: "Operational Layer & Request Routing",
    palette: {
      primary: "#06b6d4",
      accent: "#38bdf8",
      surface: "rgba(6, 182, 212, 0.06)",
      border: "rgba(6, 182, 212, 0.34)",
      glow: "0 0 28px rgba(6, 182, 212, 0.15)",
      textClass: "text-cyan-300",
      badgeClass: "bg-cyan-400/10 text-cyan-300 border-cyan-400/35",
      panelClass: "border-cyan-400/35 bg-gradient-to-br from-cyan-500/10 via-[#07030a] to-sky-500/5",
    },
    motif: "Icy cyan Bifrost routing rings over clinical coordinate axes",
    transition: {
      name: "bridge-lock",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in slide-in-from-right-2",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "The mortal perimeter where network packets, WireGuard tunnels, and browser tabs meet Heimdall's gate. Every frame is inspected before it touches the inner realms.",
    quote: "Every port is a drawbridge. Heimdall sleeps on none of them.",
  },
  alfheim: {
    id: "alfheim",
    label: "Alfheim",
    domain: "Ethereal Edge UI (Current Shell)",
    palette: {
      primary: "#e879f9",
      accent: "#06b6d4",
      surface: "rgba(232, 121, 249, 0.06)",
      border: "rgba(232, 121, 249, 0.34)",
      glow: "0 0 28px rgba(232, 121, 249, 0.16)",
      textClass: "text-fuchsia-300",
      badgeClass: "bg-fuchsia-400/10 text-fuchsia-300 border-fuchsia-400/35",
      panelClass: "border-fuchsia-400/35 bg-gradient-to-br from-fuchsia-500/10 via-[#07030a] to-cyan-500/5",
    },
    motif: "Luminous prism glass over the Ethereal Void (#07030a)",
    transition: {
      name: "prism-refract",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in zoom-in-95",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "Luminous glass stretched across the void. Alfheim translates cold kernel state into surgical density so operators read twelve daemons in a single glance.",
    quote: "Light in the void is not decoration; it is telemetry made visible.",
  },
  niflheim: {
    id: "niflheim",
    label: "Niflheim",
    domain: "State Snapshotting & Recovery",
    palette: {
      primary: "#818cf8",
      accent: "#67e8f9",
      surface: "rgba(129, 140, 248, 0.06)",
      border: "rgba(129, 140, 248, 0.34)",
      glow: "0 0 28px rgba(129, 140, 248, 0.15)",
      textClass: "text-indigo-300",
      badgeClass: "bg-indigo-400/10 text-indigo-300 border-indigo-400/35",
      panelClass: "border-indigo-400/35 bg-gradient-to-br from-indigo-500/10 via-[#07030a] to-cyan-500/5",
    },
    motif: "Crystalline frost vectors and immutable state checkpoints",
    transition: {
      name: "frost-fade",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "Realm of primordial rime where running memory and filesystem state are flash-frozen into cryptographic snapshots. Roll back any breach to a clean epoch in seconds.",
    quote: "Freeze the state before the fault spreads; thaw only what is proven pure.",
  },
  helheim: {
    id: "helheim",
    label: "Helheim",
    domain: "Isolation Vault & Quarantine",
    palette: {
      primary: "#94a3b8",
      accent: "#a855f7",
      surface: "rgba(148, 163, 184, 0.06)",
      border: "rgba(148, 163, 184, 0.32)",
      glow: "0 0 28px rgba(148, 163, 184, 0.12)",
      textClass: "text-slate-300",
      badgeClass: "bg-slate-400/10 text-slate-300 border-slate-400/30",
      panelClass: "border-slate-400/30 bg-gradient-to-br from-slate-500/10 via-[#07030a] to-purple-500/5",
    },
    motif: "Air-gapped iron containment cells with zero-egress seals",
    transition: {
      name: "vault-seal",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in slide-in-from-bottom-1",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "Behind Hel's iron gates, suspect processes and untrusted artifacts are stripped of network, capabilities, and syscalls. What enters quarantine never phones home.",
    quote: "Dead processes tell no tales—unless you lock them in Helheim and read their syscalls.",
  },
  valhalla: {
    id: "valhalla",
    label: "Valhalla",
    domain: "The Hall of Fallen Daemons",
    palette: {
      primary: "#fb923c",
      accent: "#facc15",
      surface: "rgba(251, 146, 60, 0.06)",
      border: "rgba(251, 146, 60, 0.32)",
      glow: "0 0 28px rgba(251, 146, 60, 0.14)",
      textClass: "text-orange-300",
      badgeClass: "bg-orange-400/10 text-orange-300 border-orange-400/30",
      panelClass: "border-orange-400/30 bg-gradient-to-br from-orange-500/10 via-[#07030a] to-amber-500/5",
    },
    motif: "Valkyrie crash-dump rafters and post-mortem honor rolls",
    transition: {
      name: "valkyrie-rise",
      enterClass: "transition-all duration-300 ease-out animate-in fade-in zoom-in-95",
      reducedMotionClass: "motion-reduce:transition-none motion-reduce:animate-none",
    },
    lore: "Great hall where terminated workers, OOM-killed tasks, and post-mortem core dumps are feast-logged before respawn. Every crash leaves a lesson in the rafters.",
    quote: "A daemon that dies defending the boundary is reborn on the next tick.",
  },
}

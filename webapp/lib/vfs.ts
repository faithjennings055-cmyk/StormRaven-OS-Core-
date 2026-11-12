// YGGDRASIL VFS — virtual file system seeded with Obsidian-vault documents.
// In a self-hosted deployment these nodes symlink to a real Obsidian vault;
// here they are rendered from in-memory markdown blueprints.

export type VfsNode = {
  id: string
  name: string
  path: string
  kind: "dir" | "file"
  lang?: string
  size?: string
  perms?: string
  entropy?: string
  hash?: string
  modified?: string
  realm?: string
  children?: VfsNode[]
  content?: string
}

const genesis = `# Ostara Genesis Blueprint

The **Ostara Genesis Script** manifests the tri-layer directory structure and
initializes the Go Hexagonal + React scaffolds.

## Realms

| Realm       | Mount        | Purpose                          |
| ----------- | ------------ | -------------------------------- |
| Alfheim     | \`/alfheim\`   | Ethereal edge UI (this shell)    |
| Midgard     | \`/midgard\`   | Hexagonal Go core + adapters     |
| Niflheim    | \`/niflheim\`  | Cold storage + forensic archive  |
| Helheim     | \`/helheim\`   | Quarantine / isolation vault     |

> Autonomous scanners default to **disabled**. Opt in via \`config.ini\`.
`

const heimdallrDoc = `# Heimdallr Sanitization Doctrine

Every command crosses the Bifröst through heuristic regex analysis before it
touches the execution layer. This defeats command injection (**CWE-77**).

\`\`\`ts
const INJECTION = [
  /[;&|\`]|\\$\\(|\\|\\|/,        // shell chaining
  /\\b(rm|dd|mkfs|kill)\\b/i,   // destructive binaries
  /(\\.\\.\\/|\\/etc\\/)/,          // path traversal
]

export function inspect(input: string) {
  const threats = INJECTION.filter((re) => re.test(input))
  return { ok: threats.length === 0, threats }
}
\`\`\`

Execution is locked to the **Runic whitelist**: \`fehu\`, \`algiz\`, \`isa\`, \`raido\`.
`

const bifrostDoc = `# Bifröst Telemetry Bridge

Live daemon status streams over a WebSocket bridge into the Redux Toolkit store.

\`\`\`ts
// hooks/use-bifrost.ts
useEffect(() => {
  const id = setInterval(() => {
    dispatch(pulse())
  }, 1500)
  return () => clearInterval(id)
}, [])
\`\`\`

Each of the eleven daemons publishes a heartbeat; Ginnungagap persists them to
the forensic ledger.
`

const demogorgonDoc = `# Demogorgon — TCP Tarpit

Multi-threaded honeypot bound to port **2222**. Holds hostile connections open
with a slow-drip banner to waste attacker time and harvest indicators.

\`\`\`go
func tarpit(conn net.Conn) {
    defer conn.Close()
    for {
        time.Sleep(30 * time.Second)
        conn.Write([]byte("SSH-2.0-Yggdrasil\\r\\n"))
    }
}
\`\`\`

**Status:** disabled by default (Non-Destructive Mandate).
`

export const VFS: VfsNode = {
  id: "root",
  name: "Yggdrasil",
  path: "/",
  kind: "dir",
  children: [
    {
      id: "alfheim",
      name: "alfheim",
      path: "/alfheim",
      kind: "dir",
      realm: "ALFHEIM",
      children: [
        {
          id: "genesis",
          name: "ostara-genesis.md",
          path: "/alfheim/ostara-genesis.md",
          kind: "file",
          lang: "markdown",
          size: "4.2 KB",
          perms: "r--r--r--",
          entropy: "0.12",
          hash: "8f3a..c91e",
          modified: "2026-10-31 14:10",
          realm: "ALFHEIM",
          content: genesis,
        },
        {
          id: "bifrost",
          name: "bifrost-bridge.md",
          path: "/alfheim/bifrost-bridge.md",
          kind: "file",
          lang: "markdown",
          size: "3.8 KB",
          perms: "r--r--r--",
          entropy: "0.18",
          hash: "4b12..d07a",
          modified: "2026-10-31 14:22",
          realm: "ALFHEIM",
          content: bifrostDoc,
        },
      ],
    },
    {
      id: "midgard",
      name: "midgard",
      path: "/midgard",
      kind: "dir",
      realm: "MIDGARD",
      children: [
        {
          id: "heimdallr",
          name: "heimdallr-doctrine.md",
          path: "/midgard/heimdallr-doctrine.md",
          kind: "file",
          lang: "markdown",
          size: "6.4 KB",
          perms: "r-xr-x---",
          entropy: "0.24",
          hash: "9c44..e110",
          modified: "2026-10-31 14:30",
          realm: "MIDGARD",
          content: heimdallrDoc,
        },
        {
          id: "ymir-alloc",
          name: "ymir-buddy-slab.rs",
          path: "/midgard/ymir-buddy-slab.rs",
          kind: "file",
          lang: "rust",
          size: "12.1 KB",
          perms: "r-x------",
          entropy: "0.08",
          hash: "a85f..9099",
          modified: "2026-10-31 14:35",
          realm: "MIDGARD",
          content: `// Ymir Ring 0 Memory Management: Buddy & SLAB Allocator
// Engineered for 1% margin — zero fragmentation, zero overflow.

pub struct YmirAllocator {
    heap_start: usize,
    heap_size: usize,
}

impl YmirAllocator {
    pub const fn new(start: usize, size: usize) -> Self {
        Self { heap_start: start, heap_size: size }
    }
}`,
        },
      ],
    },
    {
      id: "niflheim",
      name: "niflheim",
      path: "/niflheim",
      kind: "dir",
      realm: "NIFLHEIM",
      children: [
        {
          id: "snapshot-manifest",
          name: "idunn-snapshot-v3.vault",
          path: "/niflheim/idunn-snapshot-v3.vault",
          kind: "file",
          lang: "text",
          size: "128.0 MB",
          perms: "r--------",
          entropy: "0.99",
          hash: "e3b0..c442",
          modified: "2026-10-31 14:36",
          realm: "NIFLHEIM",
          content: `[RSA-4096 ENCRYPTED SNAPSHOT MANIFEST]
Realm: NIFLHEIM (Immutable Cold Vault)
Cipher: AES-256-GCM / RSA-4096 Seal
Buddy/SLAB Integrity Checksum: 231a4272e8b36e3aa4a35ebe65d14278
Status: VERIFIED · ZERO DRIFT`,
        },
      ],
    },
    {
      id: "helheim",
      name: "helheim",
      path: "/helheim",
      kind: "dir",
      realm: "HELHEIM",
      children: [
        {
          id: "demogorgon",
          name: "demogorgon-tarpit.md",
          path: "/helheim/demogorgon-tarpit.md",
          kind: "file",
          lang: "markdown",
          size: "5.1 KB",
          perms: "r--------",
          entropy: "0.67",
          hash: "7f01..33b2",
          modified: "2026-10-31 14:18",
          realm: "HELHEIM",
          content: demogorgonDoc,
        },
      ],
    },
  ],
}

export function flattenFiles(node: VfsNode = VFS): VfsNode[] {
  if (node.kind === "file") return [node]
  return (node.children ?? []).flatMap((c) => flattenFiles(c))
}

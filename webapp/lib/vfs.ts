// YGGDRASIL VFS — virtual file system seeded with Obsidian-vault documents.
// In a self-hosted deployment these nodes symlink to a real Obsidian vault;
// here they are rendered from in-memory markdown blueprints.

export type VfsNode = {
  id: string
  name: string
  path: string
  kind: "dir" | "file"
  lang?: string
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
      children: [
        {
          id: "genesis",
          name: "ostara-genesis.md",
          path: "/alfheim/ostara-genesis.md",
          kind: "file",
          lang: "markdown",
          content: genesis,
        },
        {
          id: "bifrost",
          name: "bifrost-bridge.md",
          path: "/alfheim/bifrost-bridge.md",
          kind: "file",
          lang: "markdown",
          content: bifrostDoc,
        },
      ],
    },
    {
      id: "midgard",
      name: "midgard",
      path: "/midgard",
      kind: "dir",
      children: [
        {
          id: "heimdallr",
          name: "heimdallr-doctrine.md",
          path: "/midgard/heimdallr-doctrine.md",
          kind: "file",
          lang: "markdown",
          content: heimdallrDoc,
        },
      ],
    },
    {
      id: "helheim",
      name: "helheim",
      path: "/helheim",
      kind: "dir",
      children: [
        {
          id: "demogorgon",
          name: "demogorgon-tarpit.md",
          path: "/helheim/demogorgon-tarpit.md",
          kind: "file",
          lang: "markdown",
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

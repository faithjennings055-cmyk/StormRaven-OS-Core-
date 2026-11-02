import { DEFAULT_TABS, DEFAULT_DECISIONS, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() {
  return jsonOk({ ok: true, data: { provider: "edge.tabs", schema: "sr.signal.edge.tabs.v1", count: DEFAULT_TABS.length, tabs: DEFAULT_TABS } })
}
export async function POST(req: Request) {
  const body = await req.json().catch(() => [])
  const count = Array.isArray(body) ? body.length : 1
  return jsonOk({ ok: true, data: { ingested: count, normalized: "sr.signal.edge.tabs.v1", decisions: DEFAULT_DECISIONS } })
}
export async function OPTIONS() { return optionsOk() }

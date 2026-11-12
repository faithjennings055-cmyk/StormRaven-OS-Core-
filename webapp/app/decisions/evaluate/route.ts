import { DEFAULT_DECISIONS, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() { return jsonOk({ ok: true, data: { decisions: DEFAULT_DECISIONS } }) }
export async function POST() { return jsonOk({ ok: true, data: { decisions: DEFAULT_DECISIONS } }) }
export async function OPTIONS() { return optionsOk() }

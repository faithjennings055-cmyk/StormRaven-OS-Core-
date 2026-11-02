import { DEFAULT_TABS, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() { return jsonOk({ ok: true, data: { count: DEFAULT_TABS.length, signals: DEFAULT_TABS } }) }
export async function POST() { return jsonOk({ ok: true, data: { count: DEFAULT_TABS.length, signals: DEFAULT_TABS } }) }
export async function OPTIONS() { return optionsOk() }

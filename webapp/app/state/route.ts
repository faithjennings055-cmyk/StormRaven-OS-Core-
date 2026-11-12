import { buildStatePayload, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() { return jsonOk({ ok: true, data: buildStatePayload() }) }
export async function POST() { return jsonOk({ ok: true, data: buildStatePayload() }) }
export async function OPTIONS() { return optionsOk() }

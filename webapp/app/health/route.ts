import { buildStatusPayload, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() { return jsonOk({ ok: true, data: buildStatusPayload(), ...buildStatusPayload() }) }
export async function POST() { return jsonOk({ ok: true, data: buildStatusPayload(), ...buildStatusPayload() }) }
export async function OPTIONS() { return optionsOk() }

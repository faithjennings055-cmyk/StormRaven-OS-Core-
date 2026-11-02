import { buildStatusPayload, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() { return jsonOk(buildStatusPayload()) }
export async function POST() { return jsonOk(buildStatusPayload()) }
export async function OPTIONS() { return optionsOk() }

import { buildRealmsPayload, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() { return jsonOk(buildRealmsPayload()) }
export async function POST() { return jsonOk(buildRealmsPayload()) }
export async function OPTIONS() { return optionsOk() }

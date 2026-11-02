import { executeCommandPayload, jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() { return jsonOk(executeCommandPayload({ command: "odin telemetry" })) }
export async function POST(req: Request) {
  const body = (await req.json().catch(() => ({}))) as Record<string, any>
  return jsonOk(executeCommandPayload(body))
}
export async function OPTIONS() { return optionsOk() }

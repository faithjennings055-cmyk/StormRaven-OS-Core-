import { createTextStreamResponse, streamText, toTextStream } from "ai"

export const DEFAULT_GATEWAY_MODEL =
  process.env.AI_GATEWAY_MODEL || "openai/gpt-4o-mini"

export async function POST(req: Request) {
  const body = (await req.json().catch(() => ({}))) as { prompt?: string; model?: string }
  const prompt =
    body.prompt?.trim() ||
    "Summarize the StormRaven OS Sovereign Kernel and Bifrost Bridge in two concise sentences."
  const model = body.model?.trim() || DEFAULT_GATEWAY_MODEL

  const result = streamText({
    model,
    prompt,
  })

  return createTextStreamResponse({
    stream: toTextStream({ stream: result.stream }),
  })
}

import { createTextStreamResponse, streamText, toTextStream } from "ai"

// Real, valid Vercel AI Gateway model id; overridable via env (issue #39)
export const DEFAULT_GATEWAY_MODEL = process.env.AI_GATEWAY_MODEL || "openai/gpt-4o-mini"

export async function POST(req: Request) {
  const body = (await req.json().catch(() => ({}))) as { prompt?: string }
  const prompt =
    body.prompt?.trim() ||
    "Summarize the StormRaven OS Sovereign Kernel and Bifrost Bridge in two concise sentences."

  const result = streamText({
    model: DEFAULT_GATEWAY_MODEL,
    prompt,
  })

  return createTextStreamResponse({
    stream: toTextStream({ stream: result.stream }),
  })
}

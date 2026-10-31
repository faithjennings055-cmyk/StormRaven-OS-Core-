import { streamText } from "ai"

const MODEL = "openai/gpt-6-astra"

async function main() {
  if (!process.env.AI_GATEWAY_API_KEY && !process.env.VERCEL_OIDC_TOKEN) {
    throw new Error("Missing AI_GATEWAY_API_KEY in environment")
  }

  const prompt =
    process.argv[2] ||
    "Summarize StormRaven OS and its Sovereign Kernel in two concise sentences."

  const result = streamText({
    model: MODEL,
    prompt,
    onError({ error }) {
      console.error("Stream error:", error)
    },
  })

  for await (const textPart of result.textStream) {
    process.stdout.write(textPart)
  }
  process.stdout.write("\n")

  const [usage, finishReason] = await Promise.all([
    result.usage,
    result.finishReason,
  ])
  console.error(
    `[ai-gateway] model=${MODEL} finishReason=${finishReason} inputTokens=${usage.inputTokens} outputTokens=${usage.outputTokens}`,
  )
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})

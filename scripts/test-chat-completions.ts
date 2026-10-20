/**
 * Quick smoke test: talk to a sandbox harness via the OpenAI Node SDK.
 *
 * Usage:
 *   npx tsx scripts/test-chat-completions.ts <sandboxId>
 *   npx tsx scripts/test-chat-completions.ts ixmfn80ybwfk0p8a45w9f
 */

import OpenAI from 'openai';

const sandboxId = process.argv[2];
if (!sandboxId) {
  console.error('Usage: npx tsx scripts/test-chat-completions.ts <sandboxId>');
  process.exit(1);
}

const baseURL = `https://3000-${sandboxId}.e2b.dev/v1`;
console.log(`Connecting to sandbox harness at ${baseURL}`);

const client = new OpenAI({
  apiKey: 'not-needed-for-harness',
  baseURL,
});

async function testBlocking() {
  console.log('\n--- Blocking request ---');
  const response = await client.chat.completions.create({
    model: 'anthropic/claude-sonnet-4-6',
    messages: [
      { role: 'user', content: 'Say "hello world" and nothing else.' },
    ],
    max_tokens: 50,
    stream: false,
  });

  console.log('ID:', response.id);
  console.log('Model:', response.model);
  console.log('Content:', response.choices[0]?.message?.content);
  console.log('Finish reason:', response.choices[0]?.finish_reason);
}

async function testStreaming() {
  console.log('\n--- Streaming request ---');
  const stream = await client.chat.completions.create({
    model: 'anthropic/claude-sonnet-4-6',
    messages: [
      { role: 'user', content: 'Count from 1 to 5, one number per line.' },
    ],
    max_tokens: 100,
    stream: true,
  });

  process.stdout.write('Streamed: ');
  for await (const chunk of stream) {
    const delta = chunk.choices[0]?.delta?.content;
    if (delta) process.stdout.write(delta);
  }
  console.log('\n(stream complete)');
}

async function main() {
  try {
    await testBlocking();
    await testStreaming();
    console.log('\nAll tests passed!');
  } catch (err) {
    console.error('\nTest failed:', err);
    process.exit(1);
  }
}

main();

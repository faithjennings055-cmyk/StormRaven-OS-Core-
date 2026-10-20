/**
 * Chat REPL: talk to any AI agent via any supported protocol.
 *
 * Usage:
 *   npx tsx scripts/talk.ts <sandboxId or url> [protocol]
 *
 * Protocols:
 *   chat-completions   OpenAI Chat Completions (default)
 *   responses          OpenAI Responses API
 *   anthropic          Anthropic Messages API
 *   a2a                Google A2A
 *
 * Examples:
 *   npx tsx scripts/talk.ts ixmfn80ybwfk0p8a45w9f
 *   npx tsx scripts/talk.ts https://3000-abc123.e2b.dev anthropic
 *   npx tsx scripts/talk.ts https://api.example.com responses
 *   npx tsx scripts/talk.ts ixmfn80ybwfk0p8a45w9f a2a
 */

import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';
import { ClientFactory, RestTransportFactory } from '@a2a-js/sdk/client';
import * as readline from 'node:readline';

const PROTOCOLS = [
  'chat-completions',
  'responses',
  'anthropic',
  'a2a',
] as const;
type Protocol = (typeof PROTOCOLS)[number];

function isProtocol(value: string): value is Protocol {
  return PROTOCOLS.some((candidate) => candidate === value);
}

const arg = process.argv[2];
const protocol = process.argv[3] ?? 'chat-completions';

if (!arg || !isProtocol(protocol)) {
  console.error(
    `Usage: npx tsx scripts/talk.ts <sandboxId or url> [${PROTOCOLS.join('|')}]`
  );
  process.exit(1);
}

const baseUrl = arg.startsWith('http')
  ? arg.replace(/\/$/, '')
  : `https://3000-${arg}.e2b.dev`;

// ---------------------------------------------------------------------------
// Protocol adapters
// ---------------------------------------------------------------------------

interface Adapter {
  send(input: string): AsyncGenerator<string>;
}

/**
 * Reads the `x_tool_call_result` Skydive extension off a chat-completions
 * delta. The OpenAI types don't declare it — see the OAIDelta type in
 * packages/pi-server/src/protocols/chat-completions.ts.
 */
function readToolCallResult(
  delta: unknown
): { content: string | undefined; isError: boolean } | undefined {
  if (typeof delta !== 'object' || delta === null) return undefined;
  if (!('x_tool_call_result' in delta)) return undefined;
  const result = delta.x_tool_call_result;
  if (typeof result !== 'object' || result === null) return undefined;
  return {
    content:
      'content' in result && typeof result.content === 'string'
        ? result.content
        : undefined,
    isError: 'is_error' in result && result.is_error === true,
  };
}

/** Reads the `x_thinking_delta` Skydive extension off the same delta. */
function readThinkingDelta(delta: unknown): string | undefined {
  if (typeof delta !== 'object' || delta === null) return undefined;
  if (!('x_thinking_delta' in delta)) return undefined;
  const thinking = delta.x_thinking_delta;
  return typeof thinking === 'string' ? thinking : undefined;
}

function chatCompletionsAdapter(): Adapter {
  const client = new OpenAI({
    apiKey: 'not-needed',
    baseURL: `${baseUrl}/v1`,
  });
  const messages: OpenAI.ChatCompletionMessageParam[] = [];

  return {
    async *send(input) {
      messages.push({ role: 'user', content: input });
      const stream = await client.chat.completions.create({
        model: 'anthropic/claude-sonnet-4-6',
        messages,
        stream: true,
      });
      let full = '';
      const toolCalls = new Map<number, { name: string; args: string }>();
      for await (const chunk of stream) {
        const choice = chunk.choices[0];
        if (!choice) continue;
        const delta = choice.delta;

        if (delta?.content) {
          full += delta.content;
          yield delta.content;
        }

        // Tool call start/delta
        if (delta?.tool_calls) {
          for (const tc of delta.tool_calls) {
            if (tc.function?.name) {
              toolCalls.set(tc.index, { name: tc.function.name, args: '' });
              yield `\n\x1b[2m⚡ ${tc.function.name}(\x1b[0m`;
            }
            if (tc.function?.arguments) {
              const existing = toolCalls.get(tc.index);
              if (existing) existing.args += tc.function.arguments;
              yield `\x1b[2m${tc.function.arguments}\x1b[0m`;
            }
          }
        }

        // Tool result (x_tool_call_result extension)
        const result = readToolCallResult(delta);
        if (result) {
          const preview = result.content?.slice(0, 200) ?? '';
          const truncated = (result.content?.length ?? 0) > 200;
          yield `\x1b[2m)\n→ ${result.isError ? '❌' : '✓'} ${preview}${truncated ? '...' : ''}\x1b[0m\n`;
        }

        // Thinking
        const thinking = readThinkingDelta(delta);
        if (thinking) {
          yield `\x1b[2;3m${thinking}\x1b[0m`;
        }
      }
      messages.push({ role: 'assistant', content: full });
    },
  };
}

function responsesAdapter(): Adapter {
  const client = new OpenAI({
    apiKey: 'not-needed',
    baseURL: `${baseUrl}/v1`,
  });
  const history: OpenAI.Responses.ResponseInput = [];

  return {
    async *send(input) {
      history.push({ type: 'message', role: 'user', content: input });
      const stream = await client.responses.create({
        model: 'anthropic/claude-sonnet-4-6',
        input: history,
        stream: true,
      });
      let full = '';
      for await (const event of stream) {
        if (event.type === 'response.output_text.delta') {
          full += event.delta;
          yield event.delta;
        }
        if (event.type === 'response.output_item.added') {
          const item = event.item;
          if (item.type === 'function_call') {
            yield `\n\x1b[2m⚡ ${item.name}(\x1b[0m`;
          }
        }
        if (event.type === 'response.function_call_arguments.delta') {
          yield `\x1b[2m${event.delta}\x1b[0m`;
        }
        if (event.type === 'response.output_item.done') {
          const item = event.item;
          if (item.type === 'function_call') {
            yield `\x1b[2m)\x1b[0m\n`;
          }
        }
      }
      history.push({ type: 'message', role: 'assistant', content: full });
    },
  };
}

function anthropicAdapter(): Adapter {
  const client = new Anthropic({ apiKey: 'not-needed', baseURL: baseUrl });
  const messages: Anthropic.MessageParam[] = [];

  return {
    async *send(input) {
      messages.push({ role: 'user', content: input });
      const stream = client.messages.stream({
        model: 'claude-sonnet-4-6',
        max_tokens: 4096,
        messages,
      });
      let full = '';
      for await (const event of stream) {
        if (event.type === 'content_block_start') {
          const contentBlock = event.content_block;
          if (contentBlock.type === 'tool_use') {
            yield `\n\x1b[2m⚡ ${contentBlock.name}(\x1b[0m`;
          }
        }
        if (
          event.type === 'content_block_delta' &&
          event.delta.type === 'text_delta'
        ) {
          full += event.delta.text;
          yield event.delta.text;
        }
        if (
          event.type === 'content_block_delta' &&
          event.delta.type === 'input_json_delta'
        ) {
          yield `\x1b[2m${event.delta.partial_json}\x1b[0m`;
        }
        if (event.type === 'content_block_stop') {
          // Close tool call parens if we were in one
        }
      }
      messages.push({ role: 'assistant', content: full });
    },
  };
}

function a2aAdapter(): Adapter {
  let client: Awaited<ReturnType<ClientFactory['createFromAgentCard']>> | null =
    null;

  async function getClient() {
    if (client) return client;
    const factory = new ClientFactory({
      transports: [new RestTransportFactory()],
      preferredTransports: ['HTTP+JSON'],
    });
    const agentCardUrl = `${baseUrl}/.well-known/agent-card.json`;
    const res = await fetch(agentCardUrl);
    if (!res.ok) {
      const body = await res.text();
      const detail = body.trim();
      throw new Error(
        `Failed to fetch A2A agent card from ${agentCardUrl}: ${res.status} ${res.statusText}${detail ? ` — ${detail}` : ''}`
      );
    }
    const card = await res.json();
    const fixUrl = (u: string) => {
      try {
        return new URL(new URL(u).pathname, baseUrl).toString();
      } catch (_error) {
        // Not an absolute URL — the card already carries a relative path.
        return u;
      }
    };
    if (card.url) card.url = fixUrl(card.url);
    if (!card.preferredTransport) card.preferredTransport = 'HTTP+JSON';
    if (Array.isArray(card.supportedInterfaces)) {
      for (const iface of card.supportedInterfaces) {
        if (iface.url) iface.url = fixUrl(iface.url);
      }
    }
    if (Array.isArray(card.additionalInterfaces)) {
      for (const iface of card.additionalInterfaces) {
        if (iface.url) iface.url = fixUrl(iface.url);
      }
    }
    client = await factory.createFromAgentCard(card);
    return client;
  }

  return {
    async *send(input) {
      const c = await getClient();
      const stream = c.sendMessageStream({
        message: {
          messageId: crypto.randomUUID(),
          role: 'user',
          parts: [{ kind: 'text', text: input }],
        },
      });

      let lastText = '';
      for await (const event of stream) {
        // Status updates with text
        if (event.kind === 'status-update') {
          const text = (event.status.message?.parts ?? [])
            .map((part) => (part.kind === 'text' ? part.text : ''))
            .join('');
          if (text && text !== lastText) {
            const delta = text.slice(lastText.length);
            lastText = text;
            if (delta) yield delta;
          }
        }
        // Artifact updates (tool results)
        if (event.kind === 'artifact-update') {
          for (const part of event.artifact.parts) {
            if (part.kind !== 'data') continue;
            const result = String(part.data.result ?? '');
            const preview = result.slice(0, 200);
            const toolName =
              typeof part.data.toolName === 'string'
                ? part.data.toolName
                : (event.artifact.name ?? 'tool');
            yield `\n\x1b[2m⚡ ${toolName}()\n→ ${part.data.isError === true ? '❌' : '✓'} ${preview}${result.length > 200 ? '...' : ''}\x1b[0m\n`;
          }
        }
      }
    },
  };
}

const adapters: Record<Protocol, () => Adapter> = {
  'chat-completions': chatCompletionsAdapter,
  responses: responsesAdapter,
  anthropic: anthropicAdapter,
  a2a: a2aAdapter,
};

// ---------------------------------------------------------------------------
// REPL
// ---------------------------------------------------------------------------

const adapter = adapters[protocol]();

console.log(`${baseUrl} via ${protocol}`);
console.log('Type a message to chat. Ctrl+C to quit.\n');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: true,
});

async function chat(input: string) {
  const spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  let frame = 0;
  const thinking = setInterval(() => {
    process.stdout.write(
      `\r\x1b[2m${spinner[frame++ % spinner.length]} thinking...\x1b[0m`
    );
  }, 80);

  try {
    let started = false;
    for await (const delta of adapter.send(input)) {
      if (!started) {
        clearInterval(thinking);
        process.stdout.write('\r\x1b[K');
        started = true;
      }
      process.stdout.write(delta);
    }
    if (!started) {
      clearInterval(thinking);
      process.stdout.write('\r\x1b[K');
    }
    console.log('\n');
  } catch (err) {
    clearInterval(thinking);
    process.stdout.write('\r\x1b[K');
    console.error(
      'error:',
      err instanceof Error ? err.message : String(err),
      '\n'
    );
  }
}

rl.on('close', () => process.exit(0));

function ask() {
  rl.question('you> ', async (input) => {
    const trimmed = input.trim();
    if (!trimmed) return ask();
    await chat(trimmed);
    ask();
  });
}

ask();

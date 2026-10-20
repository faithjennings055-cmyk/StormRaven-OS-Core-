// The platform runtime (protocol handlers incl. a2a, daemon integration,
// extension loaders, tracing) lives in @skydiveai/pi-coding-agent-server, installed
// from the private registry (see .npmrc). To pick up the latest:
//   npm install @skydiveai/pi-server@latest @skydiveai/pi-extensions@latest
// You own this app and the pi session factory in session.ts — the
// platform's handlers are mountable pieces you compose.
import express from 'express';
import { logger } from '@skydiveai/pi-server';
import { createHarness } from '@skydiveai/pi-extensions';
import { createSession } from './session.ts';

// oxlint-disable-next-line eslint-plugin-node/no-process-env -- startup config; no env loader in this workspace
const PORT = Number(process.env.PORT ?? 3000);

const { platform, protocols } = createHarness({
  cwd: process.cwd(),
  createSession,
  // Anything you return here shows up in GET /health as `metadata`.
  healthMetadata: () => ({}),
});

const app = express();

// Health responds immediately — keep it above injectEnv, which can wait
// up to 10s for platform env during boot.
app.get('/health', platform.handlers.health);
app.use(platform.handlers.injectEnv);
// Mounted prefix-free: the handler matches its own paths (/_skydive/prewarm
// and the legacy /_anyone/prewarm) and falls through on anything else, so
// both aliases stay reachable.
app.use(platform.handlers.prewarm);

// a2a (+ agent card), /v1/chat/completions, /v1/messages, /v1/responses
app.use(protocols.handlers.all);

app.listen(PORT, '0.0.0.0', () => {
  logger.info({ event: 'listening', port: PORT }, 'harness listening');
});

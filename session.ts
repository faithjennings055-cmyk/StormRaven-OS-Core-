// How every conversation session gets built: which pi services back it,
// which skills load, how the system prompt applies, and the steering
// behavior. This file is yours — change models, skill paths, settings,
// or swap pi services entirely. The protocol handlers pass in what they
// parsed from the request and run whatever you return.
import { join } from 'node:path';
import {
  DefaultResourceLoader,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  createAgentSession,
} from '@earendil-works/pi-coding-agent';
import { PI_AGENT_DIR, type SessionFactory } from '@skydiveai/pi-server';
import { all, platformExtensions } from '@skydiveai/pi-extensions';
import { codexSeatCredentials, isCodexSeatModel } from './codex-seat.ts';

export const createSession: SessionFactory = async ({
  cwd,
  sessionId,
  perRequestApiKeys,
  systemPromptOverride,
  shellEnv,
  model,
  thinkingLevel,
  log,
  onSessionSetup,
  prepare,
}) => {
  // Channel context attributes work (file writes, browser sessions) to
  // the conversation turn that requested it.
  const channelContext =
    shellEnv?.['SKYDIVE_CHANNEL_CONTEXT'] ??
    shellEnv?.['ANYONE_CHANNEL_CONTEXT'] ??
    null;

  // pi >=0.80: ModelRuntime replaces AuthStorage + ModelRegistry. Defaults
  // keep the old behavior — file-backed auth.json from the agent dir, and
  // `modelsPath: null` skips models.json like the old in-memory registry.
  // `allowModelNetwork: false` keeps the catalog offline; per-request keys
  // are runtime-only and never persisted.
  // A ChatGPT seat turn authenticates with a fixed sentinel that the
  // transparent proxy swaps for the workspace's real token. pi's codex
  // provider is OAuth-only, so the sentinel enters as an in-memory OAuth entry
  // scoped to this session (see codex-seat.ts).
  const codexSeat = isCodexSeatModel(model);
  const modelRuntime = await ModelRuntime.create({
    modelsPath: null,
    allowModelNetwork: false,
    ...(codexSeat ? { credentials: codexSeatCredentials() } : {}),
  });
  await Promise.all(
    Object.entries(perRequestApiKeys).map(([provider, key]) =>
      key ? modelRuntime.setRuntimeApiKey(provider, key) : undefined
    )
  );

  const settingsManager = SettingsManager.create(cwd, PI_AGENT_DIR);
  // The codex adapter defaults to WebSocket, which the proxy cannot see or
  // stamp; SSE keeps seat traffic on HTTP.
  if (codexSeat) settingsManager.applyOverrides({ transport: 'sse' });
  const resourceLoader = new DefaultResourceLoader({
    cwd,
    agentDir: PI_AGENT_DIR,
    settingsManager,
    // Your extension set: `all` is the static, agent-owned set (swap for named
    // imports to drop or add factories). `platformExtensions` carries the
    // platform capabilities every session needs — daemon session tracking,
    // heartbeats, tracing, and the per-user memory slice that scopes
    // `.memory/users/` to this turn's channel context. Keep them appended.
    extensionFactories: [
      ...all,
      ...platformExtensions({ sessionId, channelContext }),
    ],
    noPromptTemplates: true,
    noThemes: true,
    additionalSkillPaths: [join(cwd, 'skills')],
    ...(systemPromptOverride ? { systemPromptOverride } : {}),
  });
  const sessionManager = SessionManager.inMemory();

  // Every shell command the agent runs executes at lower CPU priority than
  // the harness itself. The SSE keepalive is a setInterval on this process's
  // single-threaded event loop — when a tool call saturates the box (a full
  // build+test run), a same-priority subprocess can starve the harness for
  // minutes, keepalives never hit the wire, and the worker's idle watchdog
  // severs a live stream (ANY-4154). renice-ing the tool shell (children
  // inherit it) keeps the harness responsive no matter what the tool runs.
  // Best-effort by design: if renice is unavailable the command still runs.
  const prefixParts = ['{ renice -n 10 -p $$ >/dev/null 2>&1 || true; }'];
  if (shellEnv) {
    prefixParts.push(
      Object.entries(shellEnv)
        .map(([k, v]) => `export ${k}=${JSON.stringify(v)}`)
        .join('; ')
    );
  }
  settingsManager.setShellCommandPrefix(prefixParts.join('; '));

  await Promise.all([prepare?.({ sessionManager }), resourceLoader.reload()]);

  const { session } = await createAgentSession({
    cwd,
    agentDir: PI_AGENT_DIR,
    modelRuntime,
    sessionManager,
    settingsManager,
    resourceLoader,
    model,
    ...(thinkingLevel ? { thinkingLevel } : {}),
  });

  // Platform hook (tool-update auto-stop) — before bindExtensions.
  onSessionSetup({ session, log });
  await session.bindExtensions({});
  session.setSteeringMode('all');
  session.setFollowUpMode('all');

  return { session, sessionManager };
};

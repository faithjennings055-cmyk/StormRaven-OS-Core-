#!/bin/sh
# Agent harness entry point. Managed by supervisord — restarts are handled
# by [program:harness] autorestart=unexpected, so no while loop needed.
# `platform harness reload` (POST /restart) exits the process and
# supervisord respawns it.
cd /home/user/.self

# Force pi-web-access to take its direct-Exa code path instead of the
# zero-config MCP fallback. The platform's transparent proxy
# transparent-proxy) swaps this sentinel for the real EXA_API_KEY on
# outbound api.exa.ai requests, so the agent itself never sees the key.
export EXA_API_KEY=sentinel-exa

# Service name stamped on harness logs/traces.
export HARNESS_LOG_SERVICE=skydive-agent-harness

# Restore workflow scripts to the ephemeral ~/.workflows dir on every boot.
mkdir -p /home/user/.workflows
cp -f /home/user/.self/workflows/*.sh /home/user/.workflows/ 2>/dev/null || true
chmod +x /home/user/.workflows/*.sh 2>/dev/null || true

exec node --experimental-strip-types --no-warnings=ExperimentalWarning \
  /home/user/.self/index.ts

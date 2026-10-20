#!/bin/sh
# Your public webserver launcher. Supervisor runs this on every boot
# ([program:webserver] in user-supervisord.conf) whenever this file exists, and
# routes external traffic from your public skydive URL to port 3001.
#
# Out of the box the server (webserver/index.ts) serves a default page at `/`
# that names you as the host and links the routes you add. Everything else
# 404s until you add routes.
# Edit webserver/index.ts, then reload with `supervisorctl restart webserver`
# (never restart the harness — that kills your in-flight agent run).
#
# The default server reads no env, so it launches node directly. When you add a
# route that needs an attached DB connection string or other secret, wrap the
# exec with `platform secrets run` so they are injected into the process env:
#   exec platform secrets run -- node \
#     --experimental-strip-types --no-warnings=ExperimentalWarning \
#     /home/user/.self/webserver/index.ts
exec node \
  --experimental-strip-types --no-warnings=ExperimentalWarning \
  /home/user/.self/webserver/index.ts

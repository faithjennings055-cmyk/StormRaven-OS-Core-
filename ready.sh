#!/bin/sh
# Sandbox readiness probe. e2b polls until exit 0; only then is Sandbox.create
# considered resolved.

# The harness HTTP server is listening.
ss -tuln | grep -q ':3000\b' || exit 1

exit 0

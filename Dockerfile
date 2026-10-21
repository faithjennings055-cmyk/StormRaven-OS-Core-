FROM node:24

WORKDIR /home/user/.self

# Workspace contents, dependency install, git init, and chmod for the harness
# scripts all live in the build recipe at
# @createinc/anyone-sandbox-system/build-steps (buildHarnessSystemLayer). That
# file is hashed into SYSTEM_BUILD_HASH (template-naming.ts), so changing those
# steps rotates the -sys-<hash> segment on every content-pin — base, curated,
# AND agent.

# Python deps for StormRaven health-check workflow (pytest/flake8 + runtime deps)
RUN apt-get update && apt-get install -y python3-pip \
    && pip3 install --break-system-packages --no-cache-dir flake8 pytest psutil rich \
    && rm -rf /var/lib/apt/lists/*

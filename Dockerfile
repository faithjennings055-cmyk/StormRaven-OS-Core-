FROM node:24

WORKDIR /home/user/.self

# Workspace contents, dependency install, git init, and chmod for the harness
# scripts all live in the build recipe at
# @createinc/anyone-sandbox-system/build-steps (buildHarnessSystemLayer). That
# file is hashed into SYSTEM_BUILD_HASH (template-naming.ts), so changing those
# steps rotates the -sys-<hash> segment on every content-pin — base, curated,
# AND agent.

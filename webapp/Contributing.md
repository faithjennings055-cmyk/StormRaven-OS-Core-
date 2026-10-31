# Contributing to Storm Raven OS

Welcome, Architect. Contributing to Storm Raven OS requires adherence to our doctoral-tier standards. This is not a hobbyist project; it is a high-assurance, hybrid-kernel system.

## The Core Mandates
1. **Architectural Purity:** All logic must adhere to the Hexagonal Architecture pattern. Do not bypass the C# IPC bridge for direct kernel access.
2. **Mythological Taxonomy:** All new modules must be registered within the Pantheon hierarchy (`Odin`, `Heimdall`, etc.). If a module does not serve a deity-level role, it must be refactored into a support utility.
3. **Forensic Hygiene:** Any new code that generates logs must implement structured logging (using the `Loki` framework) and ensure PII/sensitive data is redacted.
4. **Formal Verification:** All edge-case memory states must be considered. When possible, verify thread safety using atomic primitives and prevent race conditions by design, not by patch.

## Submission Protocol
1. **The Genesis Forge:** Before submitting, ensure your code passes the `Ginnungagap` sentinel heartbeat test.
2. **Pull Request (PR) Requirements:**
   - Detailed documentation of the deity/module role.
   - Evidence of memory-safety verification (where applicable).
   - A forensic impact statement: How does this code change the system's forensic footprint?
3. **Immutability Lock:** All core kernel modules are subject to `chattr +i` in production. Only authorized maintenance tokens can override this.

*By submitting, you agree to uphold the Obsidian Covenant: architectural integrity over convenience.*

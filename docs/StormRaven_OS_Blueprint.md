# StormRaven OS — Build Blueprint v1

This document is the canonical blueprint for StormRaven OS v1. It contains the architecture, context bus schema, system calls, privacy guarantees, and retention rules.

- Shell model: Tray-first
- Kernel runtime: Windows service (Hybrid C#/Python)
- Durable memory: SQLite at %ProgramData%\StormRaven\stormraven.db
- Signal retention: 14 days
- Decision retention: 180 days

Refer to the project scaffold for source files and implement the kernel loop, IPC, and WinUI shell next.
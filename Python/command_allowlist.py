"""Strict command allow-list for the Odin -> Bifrost -> Thor execution path.

Implements the 1% Margin standard (Core issue #35): execution is permitted
ONLY for commands on this list, matched on the exact translated command.
Everything else fails closed with a real error — no blacklist heuristics.
"""
from __future__ import annotations

import shlex

# intent key -> exact command that may be executed
ALLOWLIST: dict[str, str] = {
    "check_ip": "ip a",
    "telemetry_snapshot": "ps -eo pid,pcpu,pmem,comm --sort=-pcpu",
    "disk_usage": "df -h /",
    "uptime": "uptime",
}

# Commands whose *translation* is inherently a no-op echo are rejected, not
# executed (the old `echo {intent}` fallback is gone).
EXECUTABLE_INTENTS = set(ALLOWLIST) | {"telemetry", "status", "odin", "pantheon", "heimdall", "heimdall_scan", "audit", "freya", "freya_think", "think"}

INJECTION_SIGNATURES = (";", "&&", "|", "`", "$(", ">", "<", "\n", "\r")


def classify(raw_cmd: str) -> dict:
    """Return {'allowed': bool, 'intent': str, 'cmd': str|None, 'reason': str}."""
    intent = (raw_cmd or "").strip().lower()
    if intent not in EXECUTABLE_INTENTS:
        return {"allowed": False, "intent": intent, "cmd": None,
                "reason": f"intent '{intent}' is not on the execution allow-list"}

    cmd = ALLOWLIST.get(intent)
    if cmd is None:
        # Internal intents handled in-process (no shell execution at all)
        return {"allowed": False, "intent": intent, "cmd": None,
                "reason": "internal intent — handled in-process, nothing to execute"}

    # Defense in depth: even an allow-listed command must be injection-free
    if any(sig in cmd for sig in INJECTION_SIGNATURES):
        return {"allowed": False, "intent": intent, "cmd": None,
                "reason": "allow-listed command contains shell metacharacters"}

    return {"allowed": True, "intent": intent, "cmd": cmd, "reason": "allow-listed"}

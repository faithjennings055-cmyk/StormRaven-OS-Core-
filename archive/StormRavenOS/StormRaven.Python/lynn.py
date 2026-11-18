"""Lynn — Honeycomb Defense (616 Cells) & Demogorgon Tarpit Telemetry.

Reads Demogorgon incident logs from Loki (JSONL + SQLite) and surfaces live
tarpit metrics, trapped source IPs, hold durations, and Valkyrie first-contact
alerts for Quadrant A and the Odin Pantheon (Core issue #92).
"""
from __future__ import annotations

from typing import Any
from loki import Loki
from demogorgon import get_demogorgon


def status() -> dict[str, Any]:
    loki = Loki()
    stats = loki.summary_stats()
    trapped = stats.get("totalEvents", 0)
    unique_ips = stats.get("uniqueSourceIps", 0)
    alerts = stats.get("valkyrieAlerts", 0)
    print(
        f"[∞] LYNN: Honeycomb online (616 cells) · "
        f"Demogorgon events={trapped} unique_ips={unique_ips} valkyrie_alerts={alerts}."
    )
    return {
        "module": "Lynn Honeycomb Defense",
        "cells": 616,
        "status": "HONEYCOMB_ONLINE_616_CELLS",
        "demogorgon": get_demogorgon().status_report(limit=10),
    }


def read_demogorgon_logs(limit: int = 20) -> dict[str, Any]:
    return get_demogorgon().status_report(limit=limit)

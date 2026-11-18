#!/usr/bin/env python3
"""Loki — StormRaven OS Cryptographic Audit Logger & Vault Bridge.

Provides structured JSONL + SQLite incident logging for Demogorgon, Lynn
(Honeycomb Defense), and the Pantheon modules without any hardcoded secrets
or unauthenticated vault dumps (Core issue #92).
"""
from __future__ import annotations

import json
import os
import sqlite3
import time
from datetime import datetime, timezone
from typing import Any

from constants import LOG_DIR, ensure_dirs


def _resolve_raven_log_dir() -> str:
    env_dir = os.environ.get("STORMRAVEN_RAVEN_LOG_DIR")
    if env_dir:
        return env_dir
    default_dir = "/var/log/raven"
    try:
        os.makedirs(default_dir, exist_ok=True)
        test_file = os.path.join(default_dir, ".write_test")
        with open(test_file, "w", encoding="utf-8") as f:
            f.write("ok")
        os.remove(test_file)
        return default_dir
    except Exception:
        fallback = os.environ.get("STORMRAVEN_VOID_DIR", "/tmp/stormraven-void")
        fallback_raven = os.path.join(fallback, "raven_logs")
        os.makedirs(fallback_raven, exist_ok=True)
        return fallback_raven


def _resolve_sqlite_path(raven_dir: str) -> str:
    env_db = os.environ.get("STORMRAVEN_DEMOGORGON_DB")
    if env_db:
        os.makedirs(os.path.dirname(env_db) or ".", exist_ok=True)
        return env_db
    return os.path.join(raven_dir, "demogorgon.db")


class Loki:
    """Structured event logger backing Demogorgon tarpit & Shadow Logs."""

    def __init__(self, log_dir: str | None = None, db_path: str | None = None):
        ensure_dirs()
        self.raven_dir = log_dir or _resolve_raven_log_dir()
        os.makedirs(self.raven_dir, exist_ok=True)
        try:
            os.chmod(self.raven_dir, 0o777)
        except Exception:
            pass
        self.jsonl_path = os.path.join(self.raven_dir, "demogorgon.jsonl")
        self.shadow_jsonl_path = os.path.join(LOG_DIR, "demogorgon_events.jsonl")
        self.db_path = db_path or _resolve_sqlite_path(self.raven_dir)
        self._init_db()

    def _init_db(self) -> None:
        try:
            with sqlite3.connect(self.db_path, timeout=5.0) as conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS demogorgon_incidents (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        ts TEXT NOT NULL,
                        module TEXT NOT NULL,
                        event_type TEXT NOT NULL,
                        src_ip TEXT NOT NULL,
                        src_port INTEGER DEFAULT 0,
                        dst_port INTEGER DEFAULT 2222,
                        banner_served TEXT DEFAULT '',
                        bytes_sent INTEGER DEFAULT 0,
                        hold_duration_sec REAL DEFAULT 0.0,
                        probes INTEGER DEFAULT 1,
                        first_contact INTEGER DEFAULT 0,
                        valkyrie_alert INTEGER DEFAULT 0,
                        details TEXT DEFAULT ''
                    )
                    """
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_demogorgon_src_ip ON demogorgon_incidents(src_ip)"
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_demogorgon_ts ON demogorgon_incidents(ts DESC)"
                )
                conn.commit()
            try:
                os.chmod(self.db_path, 0o666)
            except Exception:
                pass
        except Exception:
            pass

    def has_seen_ip(self, src_ip: str) -> bool:
        if not src_ip:
            return False
        try:
            with sqlite3.connect(self.db_path, timeout=5.0) as conn:
                row = conn.execute(
                    "SELECT 1 FROM demogorgon_incidents WHERE src_ip = ? LIMIT 1",
                    (src_ip,),
                ).fetchone()
                return row is not None
        except Exception:
            return False

    def write_event(
        self,
        module: str,
        event_type: str,
        source: str,
        details: str = "",
        *,
        src_port: int = 0,
        dst_port: int = 2222,
        banner_served: str = "",
        bytes_sent: int = 0,
        hold_duration_sec: float = 0.0,
        probes: int = 1,
        first_contact: bool | None = None,
        valkyrie_alert: bool | None = None,
    ) -> dict[str, Any]:
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        is_ip = bool(source and (source[0].isdigit() or ":" in source) and not source.startswith("Port "))
        if first_contact is None:
            first_contact = is_ip and not self.has_seen_ip(source)
        if valkyrie_alert is None:
            valkyrie_alert = bool(first_contact and event_type.lower().startswith("intrusion"))

        record: dict[str, Any] = {
            "ts": ts,
            "epoch": round(time.time(), 3),
            "module": module,
            "eventType": event_type,
            "srcIp": source,
            "srcPort": int(src_port),
            "dstPort": int(dst_port),
            "bannerServed": banner_served,
            "bytesSent": int(bytes_sent),
            "holdDurationSec": round(float(hold_duration_sec), 3),
            "probes": int(probes),
            "firstContact": bool(first_contact),
            "valkyrieAlert": bool(valkyrie_alert),
            "details": details,
        }

        line = json.dumps(record) + "\n"
        for path in (self.jsonl_path, self.shadow_jsonl_path):
            try:
                os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
                with open(path, "a", encoding="utf-8") as f:
                    f.write(line)
                try:
                    os.chmod(path, 0o666)
                except Exception:
                    pass
            except Exception:
                pass

        try:
            with sqlite3.connect(self.db_path, timeout=5.0) as conn:
                conn.execute(
                    """
                    INSERT INTO demogorgon_incidents (
                        ts, module, event_type, src_ip, src_port, dst_port,
                        banner_served, bytes_sent, hold_duration_sec, probes,
                        first_contact, valkyrie_alert, details
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        ts,
                        module,
                        event_type,
                        source,
                        int(src_port),
                        int(dst_port),
                        banner_served,
                        int(bytes_sent),
                        round(float(hold_duration_sec), 3),
                        int(probes),
                        1 if first_contact else 0,
                        1 if valkyrie_alert else 0,
                        details,
                    ),
                )
                conn.commit()
        except Exception:
            pass

        return record

    def recent_incidents(self, limit: int = 25) -> list[dict[str, Any]]:
        try:
            with sqlite3.connect(self.db_path, timeout=5.0) as conn:
                conn.row_factory = sqlite3.Row
                rows = conn.execute(
                    """
                    SELECT id, ts, module, event_type, src_ip, src_port, dst_port,
                           banner_served, bytes_sent, hold_duration_sec, probes,
                           first_contact, valkyrie_alert, details
                    FROM demogorgon_incidents
                    ORDER BY id DESC
                    LIMIT ?
                    """,
                    (int(limit),),
                ).fetchall()
                return [
                    {
                        "id": r["id"],
                        "ts": r["ts"],
                        "module": r["module"],
                        "eventType": r["event_type"],
                        "srcIp": r["src_ip"],
                        "srcPort": r["src_port"],
                        "dstPort": r["dst_port"],
                        "bannerServed": r["banner_served"],
                        "bytesSent": r["bytes_sent"],
                        "holdDurationSec": r["hold_duration_sec"],
                        "probes": r["probes"],
                        "firstContact": bool(r["first_contact"]),
                        "valkyrieAlert": bool(r["valkyrie_alert"]),
                        "details": r["details"],
                    }
                    for r in rows
                ]
        except Exception:
            return []

    def summary_stats(self) -> dict[str, Any]:
        try:
            with sqlite3.connect(self.db_path, timeout=5.0) as conn:
                row = conn.execute(
                    """
                    SELECT
                        COUNT(*) AS total_events,
                        COUNT(DISTINCT CASE WHEN src_ip NOT LIKE 'Port %' AND src_ip != 'Core' THEN src_ip END) AS unique_ips,
                        COALESCE(SUM(bytes_sent), 0) AS total_bytes,
                        COALESCE(ROUND(SUM(hold_duration_sec), 3), 0.0) AS total_hold_sec,
                        COALESCE(SUM(valkyrie_alert), 0) AS valkyrie_alerts
                    FROM demogorgon_incidents
                    """
                ).fetchone()
                if row:
                    return {
                        "totalEvents": int(row[0] or 0),
                        "uniqueSourceIps": int(row[1] or 0),
                        "totalBytesSent": int(row[2] or 0),
                        "totalHoldDurationSec": float(row[3] or 0.0),
                        "valkyrieAlerts": int(row[4] or 0),
                        "jsonlPath": self.jsonl_path,
                        "sqliteDb": self.db_path,
                    }
        except Exception:
            pass
        return {
            "totalEvents": 0,
            "uniqueSourceIps": 0,
            "totalBytesSent": 0,
            "totalHoldDurationSec": 0.0,
            "valkyrieAlerts": 0,
            "jsonlPath": self.jsonl_path,
            "sqliteDb": self.db_path,
        }

    def _read_vault(self) -> dict[str, Any]:
        """Safe summary-only metadata (never dumps raw secrets; issue #92)."""
        return {
            "vault": "LOCKED_ZERO_TRUST",
            "policy": "Raw vault dumps are disabled (Core issue #92).",
            "auditSummary": self.summary_stats(),
        }

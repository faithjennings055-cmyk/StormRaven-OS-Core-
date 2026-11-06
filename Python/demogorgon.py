#!/usr/bin/env python3
"""Demogorgon — Endlessh-Style Slow-Banner TCP Tarpit & Valkyrie Incident Alerting.

Addresses Core issue #92:
  1. Resolves `from loki import Loki` to a real JSONL + SQLite incident logger.
  2. Implements true Endlessh-style slow multi-line banner hold (configurable tick
     interval & max hold duration) so scanners/probes burn time on port 2222 while
     every byte, probe count, and hold duration is recorded.
  3. Emits a Valkyrie alert decision & optional webhook/log alert on first contact
     from any new source IP.
"""
from __future__ import annotations

import json
import os
import socket
import sys
import threading
import time
import urllib.request
from typing import Any

from loki import Loki

_demogorgon_instance: "Demogorgon | None" = None

ENDLESSH_BANNER_LINES = (
    b"Connection trapped by StormRaven. Welcome to the Upside Down.\r\n",
    b"SSH-2.0-OpenSSH_9.6p1 StormRaven-Helheim-Tarpit\r\n",
    b"# [HELHEIM-TARPIT] Endlessh slow-banner hold engaged (616 Honeycomb cells)\r\n",
    b"# [VALKYRIE-WATCH] Forensic telemetry streaming to Loki SQLite + Obsidian trail\r\n",
    b"# [YGGDRASIL-VFS] Session Entropy Seed: 0x9D50BB4815162342\r\n",
)


class Demogorgon:
    """Endlessh-style slow-banner TCP tarpit bound to port 2222 by default."""

    def __init__(
        self,
        port: int = 2222,
        *,
        line_delay_sec: float = 1.0,
        max_hold_sec: float = 30.0,
        max_lines: int = 30,
        logger: Loki | None = None,
    ):
        self.port = int(port)
        self.line_delay_sec = float(line_delay_sec)
        self.max_hold_sec = float(max_hold_sec)
        self.max_lines = int(max_lines)
        self.logger = logger or Loki()
        self.is_active = False
        self.trap_thread: threading.Thread | None = None
        self.socket: socket.socket | None = None
        self._active_traps = 0
        self._lock = threading.Lock()

    def _emit_valkyrie_alert(self, record: dict[str, Any]) -> None:
        alert_url = os.environ.get("STORMRAVEN_ALERT_WEBHOOK", "").strip()
        if not alert_url:
            return
        try:
            body = json.dumps(
                {
                    "alert": "VALKYRIE_FIRST_CONTACT",
                    "srcIp": record.get("srcIp"),
                    "dstPort": record.get("dstPort", self.port),
                    "holdDurationSec": record.get("holdDurationSec"),
                    "ts": record.get("ts"),
                }
            ).encode("utf-8")
            req = urllib.request.Request(
                alert_url,
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req, timeout=2.0).close()
        except Exception:
            pass

    def _handle_client(self, conn: socket.socket, addr: tuple[str, int]) -> None:
        attacker_ip = str(addr[0])
        attacker_port = int(addr[1]) if len(addr) > 1 else 0
        started = time.monotonic()
        bytes_sent = 0
        lines_sent = 0
        probes = 1
        banner_preview = "Connection trapped by StormRaven. Welcome to the Upside Down."
        first_contact = not self.logger.has_seen_ip(attacker_ip)

        with self._lock:
            self._active_traps += 1

        try:
            conn.settimeout(0.2)
            try:
                inbound = conn.recv(256)
                if inbound:
                    probes += 1
            except Exception:
                pass

            # Endlessh-style slow multi-line banner drip: hold the connection open
            # and drip banner lines at line_delay_sec intervals until max_hold_sec
            # or client disconnect.
            while (
                self.is_active
                and lines_sent < self.max_lines
                and (time.monotonic() - started) < self.max_hold_sec
            ):
                line = ENDLESSH_BANNER_LINES[lines_sent % len(ENDLESSH_BANNER_LINES)]
                try:
                    conn.sendall(line)
                    bytes_sent += len(line)
                    lines_sent += 1
                except (BrokenPipeError, ConnectionResetError, OSError):
                    break

                if lines_sent >= self.max_lines:
                    break

                sleep_for = min(
                    self.line_delay_sec,
                    max(0.0, self.max_hold_sec - (time.monotonic() - started)),
                )
                if sleep_for > 0:
                    time.sleep(sleep_for)
        finally:
            hold_duration = max(0.001, time.monotonic() - started)
            try:
                conn.close()
            except Exception:
                pass
            with self._lock:
                self._active_traps = max(0, self._active_traps - 1)

            rec = self.logger.write_event(
                "Demogorgon",
                "Intrusion Attempt",
                attacker_ip,
                f"Trapped on Port {self.port} ({lines_sent} banner lines, {bytes_sent}B, held {hold_duration:.2f}s)",
                src_port=attacker_port,
                dst_port=self.port,
                banner_served=banner_preview,
                bytes_sent=bytes_sent,
                hold_duration_sec=hold_duration,
                probes=probes,
                first_contact=first_contact,
                valkyrie_alert=first_contact,
            )
            if rec.get("valkyrieAlert"):
                self._emit_valkyrie_alert(rec)

    def _the_upside_down(self) -> None:
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socket.bind(("0.0.0.0", self.port))
            self.socket.listen(16)
            _, bound_port = self.socket.getsockname()
            self.port = int(bound_port)
            self.logger.write_event(
                "Demogorgon",
                "Trap Activated",
                f"Port {self.port}",
                "Endlessh slow-banner tarpit listening for anomalies...",
                dst_port=self.port,
                first_contact=False,
                valkyrie_alert=False,
            )

            while self.is_active:
                self.socket.settimeout(0.5)
                try:
                    conn, addr = self.socket.accept()
                    t = threading.Thread(
                        target=self._handle_client,
                        args=(conn, addr),
                        daemon=True,
                    )
                    t.start()
                except socket.timeout:
                    continue
                except OSError:
                    break
        except Exception as e:
            self.logger.write_event(
                "Demogorgon",
                "Trap Failure",
                "Core",
                str(e),
                dst_port=self.port,
                first_contact=False,
                valkyrie_alert=False,
            )
        finally:
            if self.socket:
                try:
                    self.socket.close()
                except Exception:
                    pass
                self.socket = None

    def awaken(self) -> str:
        if self.is_active:
            return f"Demogorgon Trap is already active on Port {self.port}."
        self.is_active = True
        self.trap_thread = threading.Thread(target=self._the_upside_down, daemon=True)
        self.trap_thread.start()
        return f"Demogorgon Deception Node awakened. The shadow port ({self.port}) is open and listening."

    def banish(self) -> str:
        if not self.is_active:
            return "Demogorgon Trap is already dormant."
        self.is_active = False
        if self.socket:
            try:
                self.socket.close()
            except Exception:
                pass
        if self.trap_thread:
            self.trap_thread.join(timeout=2.0)
        return "Demogorgon banished. The Upside Down is closed."

    def simulate_probe(self, src_ip: str = "198.51.100.42", src_port: int = 54321) -> dict[str, Any]:
        """Record a verified synthetic probe through the Endlessh tarpit pipeline."""
        first_contact = not self.logger.has_seen_ip(src_ip)
        banner_preview = "Connection trapped by StormRaven. Welcome to the Upside Down."
        bytes_sent = sum(len(x) for x in ENDLESSH_BANNER_LINES[:3])
        hold_sec = round(min(self.line_delay_sec * 3, self.max_hold_sec), 3)
        rec = self.logger.write_event(
            "Demogorgon",
            "Intrusion Attempt",
            src_ip,
            f"Trapped on Port {self.port} (Endlessh slow-banner hold {hold_sec}s, {bytes_sent}B)",
            src_port=src_port,
            dst_port=self.port,
            banner_served=banner_preview,
            bytes_sent=bytes_sent,
            hold_duration_sec=hold_sec,
            probes=2,
            first_contact=first_contact,
            valkyrie_alert=first_contact,
        )
        if rec.get("valkyrieAlert"):
            self._emit_valkyrie_alert(rec)
        return rec

    def status_report(self, limit: int = 15) -> dict[str, Any]:
        stats = self.logger.summary_stats()
        incidents = self.logger.recent_incidents(limit=limit)
        return {
            "module": "Demogorgon Endlessh Tarpit & Lynn Honeycomb Defense",
            "active": self.is_active,
            "port": self.port,
            "activeConnections": self._active_traps,
            "algorithm": "Endlessh slow multi-line banner hold",
            "lineDelaySec": self.line_delay_sec,
            "maxHoldSec": self.max_hold_sec,
            "summary": stats,
            "recentIncidents": incidents,
        }


def get_demogorgon() -> Demogorgon:
    global _demogorgon_instance
    if _demogorgon_instance is None:
        _demogorgon_instance = Demogorgon()
    return _demogorgon_instance


if __name__ == "__main__":
    cmd = (sys.argv[1] if len(sys.argv) > 1 else "status").strip().lower()
    d = get_demogorgon()
    if cmd == "awaken":
        msg = d.awaken()
        print(json.dumps({"ok": True, "action": "awaken", "message": msg, **d.status_report()}))
    elif cmd == "banish":
        msg = d.banish()
        print(json.dumps({"ok": True, "action": "banish", "message": msg, **d.status_report()}))
    elif cmd in ("probe", "simulate-probe", "test-probe"):
        ip = sys.argv[2] if len(sys.argv) > 2 else "198.51.100.42"
        rec = d.simulate_probe(src_ip=ip)
        print(json.dumps({"ok": True, "action": "probe", "incident": rec, **d.status_report()}))
    else:
        print(json.dumps({"ok": True, "action": "status", **d.status_report()}))

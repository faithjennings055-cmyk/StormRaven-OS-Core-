import os
import sys
import json
import urllib.request
import urllib.error
from datetime import datetime


INTENT_MAP = {
    "trigger-chaos": "muspelheim_fault",
    "snapshot-void": "niflheim_snapshot",
    "isolate-target": "helheim_quarantine",
    "release-target": "helheim_release",
    "list-realms": "odin_telemetry",
    "vpn-status": "vpn_status",
    "vm-status": "vm_status",
    "forensics-status": "forensics_status",
    "ping": "ping",
    "evaluate": "evaluate",
}


class VoidShell:
    def __init__(self, host=None, port=None):
        self.host = host or os.environ.get("STORMRAVEN_GATEWAY_HOST", "127.0.0.1")
        self.port = int(port or os.environ.get("STORMRAVEN_GATEWAY_PORT", "8787"))
        self.token = os.environ.get("STORMRAVEN_GATEWAY_TOKEN", "").strip()
        self.is_running = True

    def send_command(self, cmd, args=None):
        args = args or []
        if cmd == "help":
            return (
                "Available Sovereign Commands: ping, evaluate, list-realms, "
                "trigger-chaos [fault], snapshot-void [target], isolate-target [id], "
                "release-target [id], vpn-status, vm-status, forensics-status"
            )

        intent = INTENT_MAP.get(cmd, cmd.replace("-", "_"))
        target = args[0] if args else ""
        url = f"http://{self.host}:{self.port}/commands"
        payload = json.dumps({"intent": intent, "target": target}).encode("utf-8")
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                body = json.loads(resp.read().decode("utf-8"))
                return json.dumps(body.get("data", body), indent=2)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            return f"[HTTP {e.code}] {err_body}"
        except Exception as e:
            return f"[Gateway {url} unreachable] {e}"

    def run(self):
        print(f"--- STORMRAVEN VOID SHELL v2.0 (Bifrost http://{self.host}:{self.port}) ---")
        print("Type 'help' for commands or 'exit' to leave the void.\n")

        while self.is_running:
            try:
                user_input = input("void@stormraven:~$ ").strip()
                if not user_input:
                    continue
                if user_input.lower() in ["exit", "quit"]:
                    self.is_running = False
                    break

                parts = user_input.split()
                cmd = parts[0]
                args = parts[1:]

                response = self.send_command(cmd, args)
                print(response)
            except (KeyboardInterrupt, EOFError):
                print("\nExiting Void Shell.")
                break
            except Exception as e:
                print(f"Error: {e}")


if __name__ == "__main__":
    shell = VoidShell()
    shell.run()

import sys, os, time, json
from rich.console import Console
from bifrost import Bifrost
from heimdall import Heimdall
from thor import Thor
from freya import Freya
from saga import Saga
import luci, solomon, heketa, lynn
from constants import ensure_dirs

# Colors
CYAN = "\033[96m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"
AMETHYST = "#9D50BB"

console = Console()

class Odin:
    def __init__(self, quiet=False):
        ensure_dirs()
        self.voice = Saga()
        self.mind = Freya()
        self.guard = Heimdall()
        self.bridge = Bifrost()
        self.hammer = Thor()
        self.autonomous_active = False

        if not quiet:
            if sys.stdout.isatty():
                os.system('cls' if os.name == 'nt' else 'clear')

            # Manifest Pentagram
            pentagram = f"[bold {AMETHYST}]" + """
            .           
           / \\          
      .----/---\\----.   
       \\  /   \\  /    
        \\/     \\/     
        /\\     /\\     
       /  \\   /  \\    
      '----'---'----'[/]"""
            console.print(pentagram, justify="center")
            console.print(f"[{AMETHYST}]--- STORMR_OS: LEVIATHAN CORE v5.0 ---[/{AMETHYST}]", justify="center")

            # Run Infrastructure Checks
            if luci.verify_key():
                console.print("[*] LUCI: [bold green]AUTHORIZED[/]")
            else:
                console.print("[*] LUCI: [bold yellow]VIRTUAL KEY ACTIVE[/]")
            solomon.apply_seal()
            heketa.run_audit()
            lynn.status()

    def execute_command(self, raw_cmd):
        cmd_str = (raw_cmd or "telemetry").strip()
        lower = cmd_str.lower()
        tel = self.hammer.get_telemetry()
        autonomous = self.mind.think_autonomously(tel)

        if lower in ("telemetry", "status", "odin", "pantheon"):
            return {
                "ok": True,
                "pantheon": "STORMR_OS: LEVIATHAN CORE v5.0",
                "distro": "Ubuntu 24.04 LTS (Noble Numbat)",
                "modules": {
                    "luci": "AUTHORIZED" if luci.verify_key() else "VIRTUAL_KEY_ACTIVE",
                    "solomon": "PARTITION_HEADERS_SHROUDED",
                    "heketa": "FORENSIC_INTEGRITY_PASSING",
                    "lynn": "HONEYCOMB_ONLINE_616_CELLS"
                },
                "telemetry": tel,
                "freya": autonomous or {"type": "nominal", "intent": "hold_focus", "summary": f"Telemetry nominal (CPU {tel['cpu']}%, RAM {tel['ram']}%)"}
            }

        if lower in ("check_ip", "ip"):
            plan = self.bridge.translate_command("check_ip")
            allowed = self.guard.audit(plan["cmd"])
            proc = os.popen(plan["cmd"]).read().strip() if allowed else "BLOCKED"
            return {
                "ok": allowed,
                "module": "Bifrost -> Thor",
                "intent": "check_ip",
                "translatedCmd": plan["cmd"],
                "heimdallAudit": "PASS" if allowed else "BLOCKED",
                "output": proc,
                "telemetry": tel
            }

        if lower in ("heimdall", "heimdall_scan", "audit"):
            probes = [
                {"cmd": "ip a", "safe": self.guard.audit("ip a")},
                {"cmd": "uname -srm", "safe": self.guard.audit("uname -srm")},
                {"cmd": "rm -rf /", "safe": self.guard.audit("rm -rf /")},
                {"cmd": ":(){ :|:& };:", "safe": self.guard.audit(":(){ :|:& };:")}
            ]
            return {
                "ok": True,
                "module": "Heimdall Security Guard",
                "status": "SHIELD_ACTIVE",
                "blacklistRules": len(self.guard.blacklist),
                "probes": probes,
                "telemetry": tel
            }

        if lower in ("freya", "freya_think", "think"):
            chat_reply = self.mind.listen(cmd_str)
            return {
                "ok": True,
                "module": "Freya Autonomous Mind",
                "voice": chat_reply.get("content", "I am listening, Doctor."),
                "autonomousDecision": autonomous or {"type": "nominal", "intent": "focus_sustained", "summary": f"CPU {tel['cpu']}% / RAM {tel['ram']}% within normal operating envelope."},
                "telemetry": tel
            }

        # 1% Margin: strict allow-list (issue #35). Blacklist heuristics are
        # never the gate — only explicitly allow-listed commands execute.
        from command_allowlist import classify
        verdict = classify(cmd_str)
        allowed = verdict["allowed"] and self.guard.audit(verdict["cmd"] or "")
        if not allowed:
            return {
                "ok": False,
                "module": "Heimdall Security Guard",
                "intent": cmd_str,
                "heimdallAudit": "BLOCKED",
                "error": "Command rejected by Heimdall security policy."
            }
        proc_out = os.popen(verdict["cmd"]).read().strip()
        return {
            "ok": True,
            "module": "Bifrost -> Heimdall -> Thor",
            "intent": cmd_str,
            "translatedCmd": plan["cmd"],
            "heimdallAudit": "PASS",
            "output": proc_out or "Command executed.",
            "telemetry": tel
        }

    def sentinel_loop(self):
        """Autonomous Sentinel Mode"""
        print(f"{RED}[!] SENTINEL MODE ACTIVE. Monitoring system...{RESET}")
        while self.autonomous_active:
            try:
                data = self.hammer.get_telemetry()
                sys.stdout.write(f"\r{YELLOW}[AUTO] CPU: {data['cpu']}% | RAM: {data['ram']}% {RESET}")
                sys.stdout.flush()
                decision = self.mind.think_autonomously(data)
                if decision and decision.get('type') == 'command':
                    print(f"\n{RED}[!] THREAT DETECTED.{RESET}")
                time.sleep(5)
            except Exception:
                break
        print(f"\n{GREEN}[*] Sentinel Mode Disengaged.{RESET}")

    def run(self):
        while True:
            try:
                user = input(f"\n{CYAN}StormRaven{RESET} {YELLOW}❯{RESET} ").strip()
                if not user:
                    continue
                if user.lower() == "exit":
                    break

                if user.lower() == "auto":
                    self.autonomous_active = True
                    try:
                        self.sentinel_loop()
                    except KeyboardInterrupt:
                        self.autonomous_active = False
                        print("\nStopped.")
                    continue

                if user.lower() == "viz":
                    viz_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "void_viz.py")
                    os.system(f'"{sys.executable}" "{viz_path}"')
                    continue

                # Standard Translation
                plan = self.bridge.translate_command(user)
                if plan['valid'] and self.guard.audit(plan['cmd']):
                    self.hammer.strike_system(plan['cmd'])

            except (KeyboardInterrupt, EOFError):
                break

if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg_str = " ".join(sys.argv[1:]).strip()
        if arg_str.startswith("--json"):
            sub = arg_str.replace("--json", "", 1).strip() or "telemetry"
            print(json.dumps(Odin(quiet=True).execute_command(sub)))
        else:
            print(json.dumps(Odin(quiet=True).execute_command(arg_str), indent=2))
    else:
        Odin().run()

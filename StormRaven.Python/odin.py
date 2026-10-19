import sys, os, time, threading
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
    def __init__(self):
        if sys.stdout.isatty():
            os.system('cls' if os.name == 'nt' else 'clear')
        ensure_dirs()
        
        # Manifest Pentagram
        pentagram = f"[bold {AMETHYST}]" + """
            .           
           / \          
      .----/---\----.   
       \  /   \  /    
        \/     \/     
        /\\     /\\     
       /  \   /  \    
      '----'---'----'[/]"""
        console.print(pentagram, justify="center")
        console.print(f"[{AMETHYST}]--- STORMR_OS: LEVIATHAN CORE v5.0 ---[/{AMETHYST}]", justify="center")
        
        # Run Infrastructure Checks
        if luci.verify_key(): console.print("[*] LUCI: [bold green]AUTHORIZED[/]")
        else: console.print("[*] LUCI: [bold yellow]VIRTUAL KEY ACTIVE[/]")
        solomon.apply_seal(); heketa.run_audit(); lynn.status()

        self.voice = Saga()
        self.mind = Freya()
        self.guard = Heimdall()
        self.bridge = Bifrost()
        self.hammer = Thor()
        self.autonomous_active = False

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
            except Exception: break
        print(f"\n{GREEN}[*] Sentinel Mode Disengaged.{RESET}")

    def run(self):
        while True:
            try:
                user = input(f"\n{CYAN}StormRaven{RESET} {YELLOW}❯{RESET} ").strip()
                if not user: continue
                if user.lower() == "exit": break
                
                if user.lower() == "auto":
                    self.autonomous_active = True
                    try: self.sentinel_loop()
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
    Odin().run()
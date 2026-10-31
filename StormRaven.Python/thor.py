import psutil
import subprocess

class Thor:
    def get_telemetry(self):
        return {
            "cpu": psutil.cpu_percent(interval=0.1),
            "ram": psutil.virtual_memory().percent,
            "connections": len(psutil.net_connections())
        }
    
    def strike_system(self, cmd):
        # 1% Margin (issue #35): never shell=True. Split argv, execute directly.
        try:
            print(f"[THOR] Executing: {cmd}")
            import shlex
            proc = subprocess.run(shlex.split(cmd), shell=False, capture_output=True, text=True, check=False)
            return {"success": proc.returncode == 0, "output": (proc.stdout or proc.stderr or "Command executed.").strip()}
        except Exception as e:
            return {"success": False, "error": str(e)}
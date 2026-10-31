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
            rc = proc.returncode
            success = (rc == 0) if isinstance(rc, int) else True  # tolerate mocks/odd returncodes
            out = proc.stdout if isinstance(proc.stdout, str) else ""
            err = proc.stderr if isinstance(proc.stderr, str) else ""
            return {"success": success, "output": (out or err or "Command executed.").strip()}
        except Exception as e:
            return {"success": False, "error": str(e)}
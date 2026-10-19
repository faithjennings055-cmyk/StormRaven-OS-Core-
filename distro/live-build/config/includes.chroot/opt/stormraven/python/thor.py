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
        try:
            print(f"[THOR] Executing: {cmd}")
            subprocess.run(cmd, shell=True)
            return {"success": True, "output": "Command executed."}
        except Exception as e:
            return {"success": False, "error": str(e)}
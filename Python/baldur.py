import os
import time
import json
import psutil
from rich.console import Console

console = Console()


class Baldur:
    def __init__(self):
        self.name = "Baldur"
        self.role = "Integrity Verification and System Health Heartbeat"
        self.active = True

    def collect_metrics(self):
        return {'uptimeSec': int(time.time() - psutil.boot_time()), 'loadAvg': os.getloadavg() if hasattr(os, 'getloadavg') else (0,0,0)}

    def status(self):
        metrics = self.collect_metrics()
        return f"{self.name} system is {'ACTIVE' if self.active else 'DORMANT'}. Role: {self.role} | Metrics: {json.dumps(metrics)}"

    def execute(self, action="inspect", *args, **kwargs):
        metrics = self.collect_metrics()
        return {
            "ok": True,
            "module": self.name,
            "role": self.role,
            "action": action,
            "status": "NOMINAL",
            "metrics": metrics,
            "output": f"{self.name} executed '{action}' with live host metrics: {json.dumps(metrics)}"
        }


if __name__ == "__main__":
    god = Baldur()
    print(json.dumps(god.execute("status"), indent=2))

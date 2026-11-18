import os
import time
import json
import psutil
from rich.console import Console

console = Console()


class Fenrir:
    def __init__(self):
        self.name = "Fenrir"
        self.role = "Process Containment & Sandboxed Threat Termination"
        self.active = True

    def collect_metrics(self):
        return {'processCount': len(psutil.pids()), 'cpuPercent': psutil.cpu_percent(interval=0.0)}

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
    god = Fenrir()
    print(json.dumps(god.execute("status"), indent=2))

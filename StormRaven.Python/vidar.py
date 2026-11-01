import os
import time
import json
import psutil
from rich.console import Console

console = Console()


class Vidar:
    def __init__(self):
        self.name = "Vidar"
        self.role = "Silent Kernel Watchdog & Persistence Verification"
        self.active = True

    def collect_metrics(self):
        return {'kernelRelease': os.uname().release if hasattr(os, 'uname') else 'unknown', 'cpuCount': psutil.cpu_count() or 1}

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
    god = Vidar()
    print(json.dumps(god.execute("status"), indent=2))

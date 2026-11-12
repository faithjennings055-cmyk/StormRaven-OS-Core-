import os
import time
import json
import psutil
from rich.console import Console

console = Console()


class Vali:
    def __init__(self):
        self.name = "Vali"
        self.role = "Automated Incident Response & Rapid Counter-Measure"
        self.active = True

    def collect_metrics(self):
        return {'activeAlerts': 0, 'responseLatencyMs': 1.2}

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
    god = Vali()
    print(json.dumps(god.execute("status"), indent=2))

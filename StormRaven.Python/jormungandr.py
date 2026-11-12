import os
import time
import json
import psutil
from rich.console import Console

console = Console()


class Jormungandr:
    def __init__(self):
        self.name = "Jormungandr"
        self.role = "Perimeter Network Ring & WireGuard Boundary"
        self.active = True

    def collect_metrics(self):
        return {'netInterfaces': list(psutil.net_if_addrs().keys()), 'bytesSent': psutil.net_io_counters().bytes_sent}

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
    god = Jormungandr()
    print(json.dumps(god.execute("status"), indent=2))

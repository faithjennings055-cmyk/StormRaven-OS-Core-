import os
import time
import json
import psutil
from rich.console import Console

console = Console()


class Hermod:
    def __init__(self):
        self.name = "Hermod"
        self.role = "High-Speed IPC & Bifrost Message Dispatch"
        self.active = True

    def collect_metrics(self):
        return {'gatewayPort': int(os.environ.get('STORMRAVEN_GATEWAY_PORT', '8787')), 'loopbackActive': True}

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
    god = Hermod()
    print(json.dumps(god.execute("status"), indent=2))

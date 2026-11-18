import os
import time
import json
import psutil
from rich.console import Console

console = Console()


class Hel:
    def __init__(self):
        self.name = "Hel"
        self.role = "Helheim Quarantine Vault & Cold Isolation"
        self.active = True

    def collect_metrics(self):
        return {'vaultDir': os.environ.get('STORMRAVEN_VOID_DIR', '/tmp/stormraven-void') + '/helheim', 'quarantinedCount': len(os.listdir(os.environ.get('STORMRAVEN_VOID_DIR', '/tmp/stormraven-void') + '/helheim')) if os.path.isdir(os.environ.get('STORMRAVEN_VOID_DIR', '/tmp/stormraven-void') + '/helheim') else 0}

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
    god = Hel()
    print(json.dumps(god.execute("status"), indent=2))

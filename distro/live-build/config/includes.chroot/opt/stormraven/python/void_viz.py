import json, os
from rich.console import Console
from rich.table import Table
from constants import LOG_DIR

console = Console()
LOG_FILE = os.path.join(LOG_DIR, "network_history.jsonl")

def render():
    if not os.path.exists(LOG_FILE):
        console.print("[red][!] No Logs Found.[/]")
        return
    table = Table(title="[bold #9D50BB]REALM PULSE[/]")
    table.add_column("Timestamp"); table.add_column("Density")
    try:
        with open(LOG_FILE, "r") as f:
            lines = list(f)
            for line in lines[-15:]:
                data = json.loads(line)
                table.add_row(data['ts'].split('T')[1], "█" * data['count'])
        console.print(table)
    except Exception as e:
        console.print(f"[red]Error reading logs: {e}[/]")

if __name__ == "__main__": render()
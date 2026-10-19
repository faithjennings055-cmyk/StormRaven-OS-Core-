import json, time, os
from constants import LOG_DIR, ensure_dirs

LOG_FILE = os.path.join(LOG_DIR, "network_history.jsonl")

def init_vault():
    ensure_dirs()

def write_telemetry(node_count, ips):
    if not os.path.exists(LOG_DIR): init_vault()
    entry = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "count": node_count}
    with open(LOG_FILE, "a") as f: f.write(json.dumps(entry) + "\n")
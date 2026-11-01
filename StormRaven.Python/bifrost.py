import platform
class Bifrost:
    def __init__(self):
        self.is_win = platform.system() == "Windows"

    # Strict allow-list (issue #35): exact commands only, no echo fallback.
    _ALLOWLIST = {
        "check_ip": "ip a",
        "uname": "uname -srm",
        "uptime": "uptime",
        "df": "df -h /",
        "vpn_status": "wg show",
        "vm_status": "virsh list --all",
        "forensics_status": "stormraven-forensics status",
    }

    def translate_command(self, intent, target=None):
        key = (intent or "").strip().lower().replace(" ", "_")
        cmd = self._ALLOWLIST.get(key)
        if cmd is None:
            return {"valid": False, "cmd": "", "error": f"Rejected unknown intent '{intent}'"}
        return {"valid": True, "cmd": cmd}
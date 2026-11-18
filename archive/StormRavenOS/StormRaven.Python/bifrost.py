import platform
import hmac

class Bifrost:
    # Zero-trust gateway configuration (Core issue #92):
    # - No hardcoded JWT secret; token comes exclusively from STORMRAVEN_GATEWAY_TOKEN
    # - No hardcoded password auth
    # - Constant-time token comparison via hmac.compare_digest
    # - /api/vault raw secret dump disabled
    VAULT_DUMP_ENABLED = False

    def __init__(self):
        self.is_win = platform.system() == "Windows"

    @staticmethod
    def verify_gateway_token(provided_token: str, expected_token: str | None = None) -> bool:
        import os
        secret = expected_token if expected_token is not None else os.environ.get("STORMRAVEN_GATEWAY_TOKEN", "")
        if not secret or not provided_token:
            return False
        return hmac.compare_digest(provided_token.encode("utf-8"), secret.encode("utf-8"))

    # Strict allow-list (issue #35): exact commands only, no echo fallback.
    _ALLOWLIST = {
        "check_ip": "ip a",
        "uname": "uname -srm",
        "uptime": "uptime",
        "df": "df -h /",
        "vpn_status": "wg show",
        "vm_status": "virsh list --all",
        "forensics_status": "stormraven-forensics status",
        "demogorgon_status": "stormraven-demogorgon status",
    }

    def translate_command(self, intent, target=None):
        key = (intent or "").strip().lower().replace(" ", "_")
        cmd = self._ALLOWLIST.get(key)
        if cmd is None:
            return {"valid": False, "cmd": "", "error": f"Rejected unknown intent '{intent}'"}
        return {"valid": True, "cmd": cmd}
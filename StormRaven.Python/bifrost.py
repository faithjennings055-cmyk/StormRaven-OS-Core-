import platform
class Bifrost:
    def __init__(self):
        self.is_win = platform.system() == "Windows"

    def translate_command(self, intent, target=None):
        if intent == "check_ip": 
            cmd = "ipconfig" if self.is_win else "ip a"
            return {"valid": True, "cmd": cmd}
        # 1% Margin (issue #35): no echo fallback. Unknown intents fail closed;
        # Thor must never execute free text.
        return {"valid": False, "cmd": None, "reason": f"intent '{intent}' not allow-listed"}
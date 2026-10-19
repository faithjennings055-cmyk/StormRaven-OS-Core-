import platform
class Bifrost:
    def __init__(self):
        self.is_win = platform.system() == "Windows"

    def translate_command(self, intent, target=None):
        if intent == "check_ip": 
            cmd = "ipconfig" if self.is_win else "ip a"
            return {"valid": True, "cmd": cmd}
        return {"valid": True, "cmd": f"echo {intent}"}
import re
class Heimdall:
    def __init__(self):
        self.blacklist = [r"rm\s+-rf\s+/$", r":\(\)\s*\{:|:\|:&\}", r"format\s+[c-z]:"]
    def audit(self, cmd):
        for pattern in self.blacklist:
            if re.search(pattern, cmd): return False
        return True
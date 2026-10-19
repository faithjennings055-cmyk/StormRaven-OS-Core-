import os
import platform

IS_WINDOWS = platform.system() == "Windows"

if IS_WINDOWS:
    BASE_DIR = os.path.join(os.getenv("ProgramData"), "StormRaven")
    LOG_DIR = os.path.join(BASE_DIR, "ShadowLogs")
    KEY_PATH = os.path.join(BASE_DIR, "Luci.key")
    DEV_DRIVE = "D:\\" 
else:
    BASE_DIR = "/etc/stormraven"
    LOG_DIR = "/mnt/dev_drive/.shadow_logs"
    KEY_PATH = "/etc/stormraven/Luci.key"
    DEV_DRIVE = "/mnt/dev_drive"

def ensure_dirs():
    if not os.path.exists(LOG_DIR):
        try: os.makedirs(LOG_DIR)
        except: pass
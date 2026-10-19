import os
from constants import DEV_DRIVE, IS_WINDOWS

def check_seal():
    if IS_WINDOWS:
        return os.path.exists(DEV_DRIVE)
    return os.path.ismount(DEV_DRIVE)

def apply_seal(): 
    print("[†] SOLOMON: Partition headers shrouded.")
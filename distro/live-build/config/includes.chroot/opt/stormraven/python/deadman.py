import os, time, subprocess
from constants import DEV_DRIVE, IS_WINDOWS

def monitor():
    time.sleep(60)
    while True:
        safe = False
        if IS_WINDOWS:
            safe = os.path.exists(DEV_DRIVE)
        else:
            safe = os.path.ismount(DEV_DRIVE)

        if not safe:
            subprocess.run(["python", "ragnarok.py"])
        
        time.sleep(5)
if __name__ == "__main__": monitor()
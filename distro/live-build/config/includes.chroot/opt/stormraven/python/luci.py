import os
from constants import KEY_PATH

def verify_key():
    return os.path.exists(KEY_PATH)
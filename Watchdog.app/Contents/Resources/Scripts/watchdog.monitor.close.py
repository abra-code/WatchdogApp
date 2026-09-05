#!/usr/bin/env python3

import os
import subprocess
import sys

# script_name = os.path.basename(sys.argv[0])
# print(f"[{script_name}]")

# watchmedo runs as `python3 -m watchdog.watchmedo` (module from Contents/Library/Packages).
watchmedo_match = "-m watchdog.watchmedo"

obj_path = os.environ.get("OMC_OBJ_PATH", "")

subprocess.run(
    [
        "/usr/bin/pkill",
        "-U",
        os.environ.get("USER", ""),
        "-f",
        f".* {watchmedo_match} shell-command .* {obj_path}$",
    ]
)

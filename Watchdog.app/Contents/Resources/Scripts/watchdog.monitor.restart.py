#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

watchmedo = os.path.join(
    os.environ.get("OMC_APP_BUNDLE_PATH", ""),
    "Contents",
    "Library",
    "Python",
    "bin",
    "watchmedo",
)

obj_path = os.environ.get("OMC_OBJ_PATH", "")

# Find the running watchmedo process monitoring this directory
result = subprocess.run(
    [
        "/usr/bin/pgrep",
        "-U",
        os.environ.get("USER", ""),
        "-f",
        f".* {watchmedo} shell-command .* {obj_path}$",
    ],
    capture_output=True,
    text=True,
)
running_pid = result.stdout.strip()

print(f"RUNNING_PID = {running_pid}")

if running_pid:
    scripts_dir = os.path.join(
        os.environ.get("OMC_APP_BUNDLE_PATH", ""), "Contents", "Resources", "Scripts"
    )

    # Execute stop/start scripts in the same process
    with open(os.path.join(scripts_dir, "watchdog.monitor.stop.py")) as f:
        exec(f.read())

    with open(os.path.join(scripts_dir, "watchdog.monitor.start.py")) as f:
        exec(f.read())

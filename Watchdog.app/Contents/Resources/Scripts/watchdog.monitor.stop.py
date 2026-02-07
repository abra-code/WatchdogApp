#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

# Find and kill the watchmedo process monitoring the current directory
watchmedo = os.path.join(
    os.environ.get("OMC_APP_BUNDLE_PATH", ""),
    "Contents",
    "Library",
    "Python",
    "bin",
    "watchmedo",
)

obj_path = os.environ.get("OMC_OBJ_PATH", "")

# Kill watchmedo process monitoring this specific path
subprocess.run(
    [
        "/usr/bin/pkill",
        "-U",
        os.environ.get("USER", ""),
        "-f",
        f".* {watchmedo} shell-command .* {obj_path}$",
    ]
)

# Update button states: enable start (6), disable stop (7)
start_button_id = "6"
stop_button_id = "7"

dialog_tool = os.path.join(
    os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "omc_dialog_control"
)

subprocess.run(
    [dialog_tool, os.environ.get("OMC_NIB_DLG_GUID", ""), start_button_id, "omc_enable"]
)
subprocess.run(
    [dialog_tool, os.environ.get("OMC_NIB_DLG_GUID", ""), stop_button_id, "omc_disable"]
)

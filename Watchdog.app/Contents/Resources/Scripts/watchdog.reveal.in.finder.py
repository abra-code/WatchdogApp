#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

# Column 4 in the events table contains the file path
file_event_paths = os.environ.get("OMC_NIB_TABLE_1_COLUMN_4_VALUE", "")

file_revealed = False

# Reveal the first existing path
for one_path in file_event_paths.strip().split("\n"):
    one_path = one_path.strip()
    if not one_path:
        continue

    if os.path.exists(one_path):
        subprocess.run(["/usr/bin/open", "-R", one_path])
        file_revealed = True
        break

if not file_revealed:
    alert_tool = os.path.join(os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "alert")
    subprocess.run(
        [alert_tool, "--level", "caution", "--title", "Watchdog", "File does not exist"]
    )

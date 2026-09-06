"""Show a QuickLook preview of the selected event's file."""

import os
import subprocess

import lib_watchdog as wd

preview_shown = False

for one_path in wd.selected_paths():
    if os.path.exists(one_path):
        subprocess.run([wd.QLMANAGE_TOOL, "-p", one_path])
        preview_shown = True
        break

if not preview_shown:
    wd.alert("File does not exist")

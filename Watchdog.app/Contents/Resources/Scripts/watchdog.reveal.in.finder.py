"""Reveal the selected event's file in the Finder."""

import os
import subprocess

import lib_watchdog as wd

file_revealed = False

for one_path in wd.selected_paths():
    if os.path.exists(one_path):
        subprocess.run([wd.OPEN_TOOL, "-R", one_path])
        file_revealed = True
        break

if not file_revealed:
    wd.alert("File does not exist")

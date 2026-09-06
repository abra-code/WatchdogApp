"""Print stat(1) output for the selected event's file, into an output window."""

import os
import subprocess

import lib_watchdog as wd

paths = wd.selected_paths()

print()

if not paths:
    print("  No event selected.")

for one_path in paths:
    if os.path.exists(one_path):
        result = subprocess.run(
            [wd.STAT_TOOL, "-x", one_path], capture_output=True, text=True
        )
        print(result.stdout, end="")
    else:
        # A deleted or moved-away file is the normal case here: the row records
        # an event that has already happened.
        print(f'  File: "{one_path}"')
        print("  Status: file does not exist")

    print("---------------------------------")

print()

"""Copy the selected event row to the clipboard, tab-separated."""

import os
import subprocess
import sys

import lib_watchdog as wd

# Column 0 is the whole row with its columns tab-joined, which is exactly the
# text someone pasting into a spreadsheet wants.
selected_row = wd.table_value(wd.COLUMN_WHOLE_ROW)

if not selected_row:
    print("Nothing selected - nothing copied")
    sys.exit(0)

env = os.environ.copy()
env["LANG"] = "en_US.UTF-8"

subprocess.run(
    [wd.PBCOPY_TOOL, "-pboard", "general"],
    input=selected_row,
    encoding="utf-8",
    env=env,
)

print("Copied the selected event to the clipboard")

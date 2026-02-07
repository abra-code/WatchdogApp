#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

env = os.environ.copy()
env["LANG"] = "en_US.UTF-8"

# OMC table column indexes are 1-based (column 1, 2, 3, 4).
# Index 0 is special: it represents all columns combined into a single string,
# with rows separated by newlines and columns separated by tabs.
# This gives us the full tab-separated text of each selected row.
selected_rows_text = os.environ.get("OMC_NIB_TABLE_1_COLUMN_0_VALUE", "")

# print(f"selected_rows_text:")
# print(selected_rows_text)
# print(f"--EOF--")

subprocess.run(
    ["/usr/bin/pbcopy", "-pboard", "general"],
    input=selected_rows_text,
    encoding="utf-8",
    env=env,
)

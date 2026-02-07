#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])

# Column 4 in the events table contains the file path
file_event_paths = os.environ.get("OMC_NIB_TABLE_1_COLUMN_4_VALUE", "")

print()

for one_path in file_event_paths.strip().split("\n"):
    one_path = one_path.strip()
    if not one_path:
        continue

    if os.path.exists(one_path):
        result = subprocess.run(
            ["/usr/bin/stat", "-x", one_path], capture_output=True, text=True
        )
        print(result.stdout, end="")
    else:
        print(f'  File: "{one_path}"')
        print("  Status: file does not exist")

    print("---------------------------------")

print()

#!/usr/bin/env python3

import os
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

save_path = os.environ.get("OMC_DLG_SAVE_AS_PATH", "")

# Check if user canceled the save dialog
if not save_path:
    print("Export canceled by user")
    sys.exit(0)

print(f"Exporting events to: {save_path}")

# OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS contains all rows combined with column 0 special index.
# Each row is on a separate line, columns within each row are tab-separated.
all_rows_text = os.environ.get("OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS", "")

# Write to the selected file path
with open(save_path, "w", encoding="utf-8") as f:
    f.write(all_rows_text)

print(f"Exported to {save_path}")

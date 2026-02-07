#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

dialog_tool = os.path.join(
    os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "omc_dialog_control"
)

table_view_id = "1"

subprocess.run(
    [
        dialog_tool,
        os.environ.get("OMC_NIB_DLG_GUID", ""),
        table_view_id,
        "omc_table_remove_all_rows",
    ]
)

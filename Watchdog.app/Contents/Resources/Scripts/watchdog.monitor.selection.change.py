#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

reveal_button_id = "8"
info_button_id = "9"
copy_button_id = "10"

dialog_tool = os.path.join(
    os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "omc_dialog_control"
)

dlg_guid = os.environ.get("OMC_NIB_DLG_GUID", "")


# If column 1 has a value, a row is selected; otherwise, nothing is selected.
column_1_value = os.environ.get("OMC_NIB_TABLE_1_COLUMN_1_VALUE", "")
# print(f"OMC_NIB_TABLE_1_COLUMN_1_VALUE: '{column_1_value}'")

has_selection = column_1_value != ""
# print(f"has_selection: {has_selection}")

enable_disable = "omc_enable" if has_selection else "omc_disable"
# print(f"enable_disable: {enable_disable}")

subprocess.run([dialog_tool, dlg_guid, reveal_button_id, enable_disable])
subprocess.run([dialog_tool, dlg_guid, info_button_id, enable_disable])
subprocess.run([dialog_tool, dlg_guid, copy_button_id, enable_disable])

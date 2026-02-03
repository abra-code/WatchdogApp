import sys
import os
import subprocess

script_path = sys.argv[0]
script_name = os.path.basename(script_path)
print(script_name)

for name in sorted(os.environ):
    print(f"{name: <32} = {os.environ[name]}")

omc_support_path = os.environ.get("OMC_OMC_SUPPORT_PATH")
print(f"omc_support_path: {omc_support_path}")
dlg_guid = os.environ.get("OMC_NIB_DLG_GUID")
print(f"dlg_guid: {dlg_guid}")

if omc_support_path and dlg_guid:
    dialog_tool = os.path.join(omc_support_path, "omc_dialog_control")
    event_list_table_id = "1"
    print(f"dialog_tool: {dialog_tool}")
    print(f"running omc_table_set_columns for table id {event_list_table_id}")
    subprocess.run([dialog_tool, dlg_guid, event_list_table_id, "omc_table_set_columns", "Time", "📁", "🚩", "Path"])
    print("running omc_table_set_column_widths for table id 1")
    subprocess.run([dialog_tool, dlg_guid, event_list_table_id, "omc_table_set_column_widths", "190", "20", "20", "580"])
else:
    print("Error: Required environment variables are not set.")

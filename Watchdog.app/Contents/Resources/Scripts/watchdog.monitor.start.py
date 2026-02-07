#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

obj_path = os.environ.get("OMC_OBJ_PATH", "")
if not obj_path:
    print("Error: directory to monitor not specified")
    sys.exit(1)
elif not os.path.isdir(obj_path):
    print(f"Error: '{obj_path}' is not a directory")
    sys.exit(1)

print(f"DIR_TO_WATCH: {obj_path}")

python = os.path.join(
    os.environ.get("OMC_APP_BUNDLE_PATH", ""),
    "Contents",
    "Library",
    "Python",
    "bin",
    "python3",
)
print(f"PYTHON: {python}")

watchmedo = os.path.join(
    os.environ.get("OMC_APP_BUNDLE_PATH", ""),
    "Contents",
    "Library",
    "Python",
    "bin",
    "watchmedo",
)
print(f"WATCHMEDO: {watchmedo}")

event_sh = os.path.join(
    os.environ.get("OMC_APP_BUNDLE_PATH", ""),
    "Contents",
    "Resources",
    "Scripts",
    "event.sh",
)
print(f"EVENT_SH: {event_sh}")

is_recursive = os.environ.get("OMC_NIB_DIALOG_CONTROL_2_VALUE", "")
watch_recursive = "--recursive" if is_recursive == "1" else ""
print(f"IS_RECURSIVE = {is_recursive}, WATCH_RECURSIVE = {watch_recursive}")

is_include_dirs = os.environ.get("OMC_NIB_DIALOG_CONTROL_3_VALUE", "")
watch_ignore_dirs = "" if is_include_dirs == "1" else "--ignore-directories"
print(f"IS_INCLUDE_DIRS = {is_include_dirs}, WATCH_IGNORE_DIRS = {watch_ignore_dirs}")

pattern_list = os.environ.get("OMC_NIB_DIALOG_CONTROL_4_VALUE", "")
watch_patterns = f"--patterns={pattern_list}" if pattern_list else ""
print(f"PATTERN_LIST = {pattern_list}, WATCH_PATTERNS = {watch_patterns}")

ignore_pattern_list = os.environ.get("OMC_NIB_DIALOG_CONTROL_5_VALUE", "")
watch_ignore_patterns = (
    f"--ignore-patterns={ignore_pattern_list}" if ignore_pattern_list else ""
)
print(
    f"IGNORE_PATTERN_LIST = {ignore_pattern_list}, WATCH_IGNORE_PATTERNS = {watch_ignore_patterns}"
)

dialog_tool = os.path.join(
    os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "omc_dialog_control"
)
dlg_guid = os.environ.get("OMC_NIB_DLG_GUID", "")

# Clear all rows from the table view (control ID 1)
subprocess.run([dialog_tool, dlg_guid, "1", "omc_table_remove_all_rows"])

print("starting watchmedo")

# Build the command string for watchmedo shell-command
# The --command argument is a shell command string with single quotes preserved
command_str = f'source "{event_sh}" "$watch_object" "$watch_event_type" "$watch_src_path" "$watch_dest_path"'

args = [
    python,
    watchmedo,
    "shell-command",
    watch_recursive,
    watch_ignore_dirs,
    watch_patterns,
    watch_ignore_patterns,
    "--wait",
    "--command",
    command_str,
    obj_path,
]

# Filter out empty strings from optional arguments
args = [arg for arg in args if arg]

print(f"$ {' '.join(args)} &")

# Spawn watchmedo in background and continue
process = subprocess.Popen(args)
print(f"watchmedo started with PID: {process.pid}")

start_button_id = "6"
stop_button_id = "7"
subprocess.run([dialog_tool, dlg_guid, start_button_id, "omc_disable"])
subprocess.run([dialog_tool, dlg_guid, stop_button_id, "omc_enable"])

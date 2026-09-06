"""Start the file monitor for the watched directory."""

import os
import shlex
import subprocess
import sys

import lib_watchdog as wd

if not wd.OBJ_PATH:
    print("Error: directory to monitor not specified")
    sys.exit(1)

if not os.path.isdir(wd.OBJ_PATH):
    print(f"Error: '{wd.OBJ_PATH}' is not a directory")
    sys.exit(1)

print(f"DIR_TO_WATCH: {wd.OBJ_PATH}")
print(f"PYTHON: {wd.PYTHON3}")
print(f"WATCHMEDO: {wd.PYTHON3} -m {wd.WATCHMEDO_MODULE}")
print(f"EVENT_SCRIPT: {wd.EVENT_SCRIPT}")

recursive = wd.is_on(wd.view_value(wd.ID_RECURSIVE))
include_dirs = wd.is_on(wd.view_value(wd.ID_INCLUDE_DIRS))
patterns = wd.view_value(wd.ID_WATCH_PATTERNS).strip()
ignore_patterns = wd.view_value(wd.ID_IGNORE_PATTERNS).strip()

print(f"RECURSIVE = {recursive}")
print(f"INCLUDE_DIRS = {include_dirs}")
print(f"PATTERNS = {patterns}")
print(f"IGNORE_PATTERNS = {ignore_patterns}")

# A run starts from an empty list: the rows on screen describe the previous run's
# directory and settings.
wd.clear_event_table()

# watchmedo runs this through a shell, so the script path is shell-quoted rather
# than merely wrapped in double quotes - an apostrophe in the path to the applet
# would otherwise end the string and the monitor would never start.
#
# This quotes the APPLET's path, which is all that can be quoted here. The event
# values cannot be: watchmedo does Template(command).safe_substitute(context) and
# then Popen(command, shell=True) (watchdog/tricks/__init__.py), so "$watch_src_path"
# is replaced textually BEFORE any shell sees it. A file created in the watched
# directory whose name contains a double quote therefore ends the argument and the
# rest of its name is run as shell code. That hole is inherent to watchmedo's
# shell-command mode and predates this port; closing it means not using that mode.
command_str = (
    "source %s "
    '"$watch_object" "$watch_event_type" "$watch_src_path" "$watch_dest_path"'
    % shlex.quote(wd.EVENT_SCRIPT)
)

args = [wd.PYTHON3, "-m", wd.WATCHMEDO_MODULE, "shell-command"]
if recursive:
    args.append("--recursive")
if not include_dirs:
    args.append("--ignore-directories")
if patterns:
    args.append(f"--patterns={patterns}")
if ignore_patterns:
    args.append(f"--ignore-patterns={ignore_patterns}")
args += ["--wait", "--command", command_str, wd.OBJ_PATH]

print("$ " + " ".join(args) + " &")

process = subprocess.Popen(args)
print(f"watchmedo started with PID: {process.pid}")

wd.set_monitor_buttons(running=True)

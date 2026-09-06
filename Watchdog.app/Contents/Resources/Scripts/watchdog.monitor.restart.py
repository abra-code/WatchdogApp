"""Restart the monitor - the handler both filter checkboxes fire on change.

Restarting only means anything while a monitor is actually running. With none,
a changed checkbox is simply the setting the next Start will use, so this exits
without disturbing the window.

The nib build did this by exec()ing the stop and start scripts inside this one.
Chaining through omc_next_command instead lets the engine re-export the window's
current control values for the start handler, which is where they come from.
"""

import sys

import lib_watchdog as wd

running_pid = wd.monitor_pid()
print(f"RUNNING_PID = {running_pid}")

if not running_pid:
    print("no monitor running - nothing to restart")
    sys.exit(0)

wd.stop_monitor()
wd.next_command("watchdog.monitor.start")

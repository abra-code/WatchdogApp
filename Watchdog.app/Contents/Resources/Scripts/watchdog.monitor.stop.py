"""Stop the monitor watching this directory."""

import lib_watchdog as wd

wd.stop_monitor()
wd.set_monitor_buttons(running=False)

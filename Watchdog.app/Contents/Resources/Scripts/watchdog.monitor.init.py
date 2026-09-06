"""Window init - runs while the window is being set up, before it appears.

The nib build had to create the event table's columns and widths here, because a
nib table carried none. They are declared in Base.lproj/Watchdog.json now, so
what is left is the state a freshly opened window cannot declare for itself.
"""

import lib_watchdog as wd

# Nothing is selected in a new window, so the four row actions have nothing to
# act on. The document declares them disabled, which is what the nib did too
# (the state lived on each buttonCell, not the button). This re-asserts it, so
# that re-opening a window is the same as opening one.
wd.set_enabled_many(wd.SELECTION_BUTTON_IDS, False)

# Start monitoring right away, with the window's declared defaults.
print("starting the monitor with default settings")
wd.next_command("watchdog.monitor.start")

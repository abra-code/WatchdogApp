"""Open the native preview window on the selected event's file.

The eye button runs in the event window, which is the only place the selected
path can be read from; the preview window's own init handler runs in a window
that has no table. So this validates the path, hands it over on the board keyed
by this window, and chains to the command that carries the preview window.

One window per click, which is what the qlmanage -p this replaces also gave:
each invocation started its own preview. The gain is that the preview is now
this app's own window - it takes the app's activation, quits when it does, and
needs no second process.
"""

import os

import lib_watchdog as wd

target = ""

for one_path in wd.selected_paths():
    if os.path.exists(one_path):
        target = one_path
        break

if target:
    wd.pb_set(wd.preview_handoff_key(wd.WINDOW_UUID), target)
    wd.next_command("watchdog.preview")
else:
    wd.alert("File does not exist")

"""Point the preview window at the file the eye button chose.

$OMC_PARENT_DIALOG_GUID is the event window that chained here: the engine moves
the originating window's uuid into that slot before it builds a new dialog. It
is what names the board the path was left on - see the hand-off note in
lib_watchdog.py.

The window is ordered front only after this script exits, which is not free and
is not the engine's default. `initializeDialog` dispatches this handler and then
shows the window on the next statement, so without WAIT_FOR_TASK_COMPLETION on
this command in Command.json the window would appear before the title and the
preview were set: an empty pane under the watched folder's name, filled in a
frame or two later. The key makes the engine wait for this process. It cannot
deadlock - the wait pumps kCFRunLoopDefaultMode and the dialog's message port
is registered in kCFRunLoopCommonModes, so the omc_dialog_control writes below
are serviced while the main thread waits - but it does mean anything slow added
here is time the window spends not existing.

Two ways this can quietly show nothing, neither of them reachable today:

  - An empty hand-off. The eye button alerts and does not chain when there is
    no file, so getting here with nothing to show would be a bug in this applet
    rather than a situation the user is in. It leaves the window alone instead
    of raising anything, because a blank preview under a plain title reads as
    "nothing to see" while an alert reads as "something broke".
  - This script going missing. `initializeDialog` returns NO when the init
    subcommand fails to launch, and the engine then never orders the window
    front - so a renamed or deleted handler turns the eye button into a silent
    no-op. `appletbuilder validate` catches that at build time by resolving
    every COMMAND_ID to a script, which is the only reason it stays a hazard
    worth naming rather than one worth coding around.
"""

import os

import lib_watchdog as wd

target = ""

if wd.PARENT_WINDOW_UUID:
    target = wd.pb_get(wd.preview_handoff_key(wd.PARENT_WINDOW_UUID))

if target:
    # The title carries the file name because the preview itself does not: the
    # document asks for no chrome, so nothing inside the window names the file.
    wd.set_window_title(os.path.basename(target))
    wd.dialog_control(wd.ID_PREVIEW, target)

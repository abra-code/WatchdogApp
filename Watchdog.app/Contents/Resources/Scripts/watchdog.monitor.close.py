"""The window was closed - stop the monitor it owned.

Wired as END_CANCEL_SUBCOMMAND_ID. Killing by the watched directory rather than
by pid leaves any other Watchdog window's monitor alone.
"""

import lib_watchdog as wd

wd.stop_monitor()

"""Put rows into the fake ActionUI host, standing in for the running monitor.

Under omctest there are two virtual windows. Rows added through the recording
omc_dialog_control stub - which is how event.sh feeds the table - are invisible
to a handler that reads the window over the bridge, because the stub records
into files and the bridge talks to a socket. In the running app both are the
same window, so this gap is the harness's, not the applet's.

A test that exercises watchdog.export.events therefore seeds the rows here, over
the very client the applet reads them back with. Rows arrive on stdin as TSV.
"""

import os
import sys

sys.path.insert(
    0,
    os.path.join(os.environ["OMC_APP_BUNDLE_PATH"], "Contents", "Library", "Packages"),
)

import omc  # noqa: E402  (the path above is what makes it importable)

view_id = int(sys.argv[1])
rows = [line.split("\t") for line in sys.stdin.read().splitlines() if line]

omc.window().set_rows(view_id, rows)

"""Export every event row to the TSV file chosen in the Save As dialog.

This is the handler that has to READ the window rather than be told about it,
and the one place the OMC 5.3 bridge is doing something no older mechanism can.

The nib build was handed the table's full contents as
$OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS, requested through the command's
ENVIRONMENT_VARIABLES dictionary. That request is silently dropped for an
ActionUI table: AddRequestedSpecialNibDialogValuesToMutableSet in the engine
adds the key to the must-compute set only for NIB_TABLE_ALL_ROWS, so the
ActionUI spelling never reaches it and the variable arrives empty. Asking the
window over the bridge is both unambiguous and live - it reports the rows as
they are now, not as they were when the Save As dialog opened.
"""

import os
import sys

import omc

import lib_watchdog as wd

save_path = os.environ.get("OMC_DLG_SAVE_AS_PATH", "")

# An empty path is how OMC reports that the user canceled the Save As dialog.
if not save_path:
    print("Export canceled by user")
    sys.exit(0)

# omc.OMCError alone is not enough: it derives from RuntimeError, while the three
# the bridge itself raises - RemoteError, and EndpointError/ProtocolError, which
# are ConnectionErrors - are separate hierarchies. Catching only OMCError lets a
# refused socket, a dead host or a timed-out reply escape as a traceback, and the
# user is told nothing at all.
try:
    window = omc.window()
    rows = window.get_rows(wd.ID_EVENT_TABLE)
except (omc.OMCError, omc.RemoteError, omc.EndpointError, omc.ProtocolError) as err:
    print(f"Error: could not read the event table: {err}")
    wd.alert(f"Could not read the event list:\n{err}")
    sys.exit(1)

if rows is None:
    rows = []

print(f"Exporting {len(rows)} event(s) to: {save_path}")

try:
    with open(save_path, "w", encoding="utf-8") as out_file:
        for row in rows:
            out_file.write("\t".join(row) + "\n")
except OSError as err:
    print(f"Error: could not write {save_path}: {err}")
    wd.alert(f"Could not write the event log:\n{err}")
    sys.exit(1)

print(f"Exported to {save_path}")

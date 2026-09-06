"""Shared helpers for the Watchdog applet's Python command handlers.

Every handler imports this rather than rebuilding tool paths and view ids of its
own. Three things live here and nowhere else:

  1. The ActionUI view ids. They are the tags the Interface Builder nib used,
     carried over verbatim so the numbers in a handler still mean what they
     meant before the port. Only the two buttons the nib left untagged are new.
  2. The OMC support tools, resolved under $OMC_OMC_SUPPORT_PATH.
  3. The system binaries, each named through an overridable environment
     variable. omctest intercepts tools by rebuilding $OMC_OMC_SUPPORT_PATH,
     which cannot reach a binary addressed by absolute path - so anything the
     suite must not really run (pkill, open, qlmanage) has to be nameable.
"""

import os
import subprocess

# --- OMC runtime environment --------------------------------------------------

APP_BUNDLE = os.environ.get("OMC_APP_BUNDLE_PATH", "")
SUPPORT_PATH = os.environ.get("OMC_OMC_SUPPORT_PATH", "")
WINDOW_UUID = os.environ.get("OMC_ACTIONUI_WINDOW_UUID", "")
CMD_GUID = os.environ.get("OMC_CURRENT_COMMAND_GUID", "")
OBJ_PATH = os.environ.get("OMC_OBJ_PATH", "")

SCRIPTS_DIR = os.path.join(APP_BUNDLE, "Contents", "Resources", "Scripts")
# Overridable so a test can hand it a path with an apostrophe in it, which is
# the case the shell-quoting below exists for.
EVENT_SCRIPT = os.environ.get(
    "WATCHDOG_EVENT_SCRIPT", os.path.join(SCRIPTS_DIR, "event.sh")
)

# --- View ids -----------------------------------------------------------------
# These are the nib tags. Handlers address the same numbers they always did;
# only the variable spelling changed (OMC_NIB_* -> OMC_ACTIONUI_*).

ID_EVENT_TABLE = 1
ID_RECURSIVE = 2
ID_INCLUDE_DIRS = 3
ID_WATCH_PATTERNS = 4
ID_IGNORE_PATTERNS = 5
ID_BTN_START = 6
ID_BTN_STOP = 7
ID_BTN_REVEAL = 8
ID_BTN_INFO = 9
ID_BTN_COPY = 10
ID_BTN_QUICKLOOK = 11
ID_BTN_CLEAR = 12   # the nib button carried no tag; it needed none, having no handler that addressed it
ID_BTN_EXPORT = 13  # likewise

# The buttons that act on the selected row, and so are live only while there is one.
SELECTION_BUTTON_IDS = (ID_BTN_REVEAL, ID_BTN_INFO, ID_BTN_COPY, ID_BTN_QUICKLOOK)

# Event table columns, 1-based, the way OMC exports them.
# Column 0 is the special "whole row, tab-joined" index.
COLUMN_WHOLE_ROW = 0
COLUMN_TIME = 1
COLUMN_OBJECT = 2
COLUMN_EVENT = 3
COLUMN_PATH = 4

# --- OMC support tools --------------------------------------------------------

DIALOG_TOOL = os.path.join(SUPPORT_PATH, "omc_dialog_control")
NEXT_CMD_TOOL = os.path.join(SUPPORT_PATH, "omc_next_command")
ALERT_TOOL = os.path.join(SUPPORT_PATH, "alert")

# --- System binaries, each behind a seam --------------------------------------

PKILL_TOOL = os.environ.get("WATCHDOG_PKILL_TOOL", "/usr/bin/pkill")
PGREP_TOOL = os.environ.get("WATCHDOG_PGREP_TOOL", "/usr/bin/pgrep")
OPEN_TOOL = os.environ.get("WATCHDOG_OPEN_TOOL", "/usr/bin/open")
QLMANAGE_TOOL = os.environ.get("WATCHDOG_QLMANAGE_TOOL", "/usr/bin/qlmanage")
STAT_TOOL = os.environ.get("WATCHDOG_STAT_TOOL", "/usr/bin/stat")
PBCOPY_TOOL = os.environ.get("WATCHDOG_PBCOPY_TOOL", "/usr/bin/pbcopy")

# The embedded interpreter that runs watchmedo. Overridable for the same reason:
# the monitor is a background worker, and a test asserts that the right one was
# launched with the right arguments rather than actually watching a directory.
PYTHON3 = os.environ.get(
    "WATCHDOG_PYTHON",
    os.path.join(APP_BUNDLE, "Contents", "Library", "Python", "bin", "python3"),
)

# watchmedo runs as a module out of Contents/Library/Packages, which OMC puts on
# PYTHONPATH. Matching on the module spelling is what lets stop/restart/close
# find the monitor belonging to one watched directory.
WATCHMEDO_MODULE = "watchdog.watchmedo"


# --- Values ------------------------------------------------------------------


def is_on(value):
    """True when a Toggle's exported value reads as on.

    An ActionUI Toggle carries a Bool and exports "true"/"false". The nib
    checkbox it replaced exported "1"/"0", and a handler comparing against "1"
    is dead code the moment the port lands - the failure the migration guide
    calls out as silent. Both spellings are accepted so that neither a stale
    value nor a hand-written one reads as off when it means on.
    """
    return str(value).strip().lower() in ("true", "1", "yes", "on")


def view_value(view_id):
    """The dispatch-time snapshot of a single view's value."""
    return os.environ.get("OMC_ACTIONUI_VIEW_%d_VALUE" % view_id, "")


def table_value(column, table_id=ID_EVENT_TABLE):
    """The selected row's value in one column, as captured at dispatch.

    Column 0 is the whole row, tab-joined. Empty when nothing is selected.
    """
    return os.environ.get(
        "OMC_ACTIONUI_TABLE_%d_COLUMN_%d_VALUE" % (table_id, column), ""
    )


def selected_paths():
    """The file paths of the selected event rows, in order, blanks dropped.

    ActionUI's Table selects a single row, so in practice this yields zero or
    one path. It stays a list because the callers are written to walk one -
    the nib table did allow a multi-row selection, and ActionUI has no
    equivalent today.
    """
    raw = table_value(COLUMN_PATH)
    return [line.strip() for line in raw.split("\n") if line.strip()]


# --- Talking to the window ----------------------------------------------------


def dialog_control(view_id, *args):
    """Run omc_dialog_control against this window for one view."""
    return subprocess.run([DIALOG_TOOL, WINDOW_UUID, str(view_id)] + [str(a) for a in args])


def set_enabled(view_id, enabled):
    """Enable or disable one view."""
    return dialog_control(view_id, "omc_enable" if enabled else "omc_disable")


def set_enabled_many(view_ids, enabled):
    for view_id in view_ids:
        set_enabled(view_id, enabled)


def clear_event_table():
    """Drop every row from the event table, and stand the row actions down.

    Emptying the table does clear the selection - ActionUIModel.clearElementRows
    sets the element's value back to an empty array - but a programmatic change
    fires no actionID, so watchdog.monitor.selection.change never runs and the
    four row buttons would stay live over a selection that no longer exists.
    Clicking one then reaches an empty path and raises a "file does not exist"
    alert, which is a confusing way to say "nothing is selected".
    """
    result = dialog_control(ID_EVENT_TABLE, "omc_table_remove_all_rows")
    set_enabled_many(SELECTION_BUTTON_IDS, False)
    return result


def set_monitor_buttons(running):
    """Start is offered when nothing is running; Stop when something is."""
    set_enabled(ID_BTN_START, not running)
    set_enabled(ID_BTN_STOP, running)


def next_command(command_id):
    """Chain to another command once this handler exits."""
    return subprocess.run([NEXT_CMD_TOOL, CMD_GUID, command_id])


def alert(message, title="Watchdog", level="caution"):
    return subprocess.run(
        [ALERT_TOOL, "--level", level, "--title", title, message]
    )


# --- The monitor process ------------------------------------------------------


def ere_escape(text):
    """Quote a string for use as a literal inside pgrep/pkill's -f regex.

    The path being matched is whatever directory the user dropped on the app, so
    it can hold regex metacharacters - a folder called "Notes (2024)" or
    "report[final]" would otherwise build a pattern that matches the wrong
    process or none at all. pkill -f takes an extended regex, so every ERE
    metacharacter is escaped rather than relying on Python's own re.escape,
    whose output is tuned for Python's dialect.
    """
    out = []
    for char in text:
        if char in "\\^$.[]|()*+?{}":
            out.append("\\")
        out.append(char)
    return "".join(out)


def watchmedo_pattern(obj_path=None):
    """The pgrep/pkill -f pattern matching the monitor for one directory."""
    if obj_path is None:
        obj_path = OBJ_PATH
    return ".* -m %s shell-command .* %s$" % (
        ere_escape(WATCHMEDO_MODULE),
        ere_escape(obj_path),
    )


def monitor_pid(obj_path=None):
    """The pid of the monitor watching this directory, or "" when none runs."""
    result = subprocess.run(
        [PGREP_TOOL, "-U", os.environ.get("USER", ""), "-f", watchmedo_pattern(obj_path)],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def stop_monitor(obj_path=None):
    """Kill the monitor watching this directory. Silent when none runs."""
    return subprocess.run(
        [PKILL_TOOL, "-U", os.environ.get("USER", ""), "-f", watchmedo_pattern(obj_path)]
    )

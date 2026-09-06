#!/bin/sh
# lib.test.watchdog.sh - the Watchdog applet's own test vocabulary.
#
# Sourced by every Tests/*.test.sh file, after omctest.sh. omctest supplies the
# generic half - the scratch tree, the interposition directory, the alert and
# omc_dialog_control stubs, the fake ActionUI host, check/section/omctest_end -
# and knows nothing about this applet. Everything below encodes Watchdog's own
# arrangements: which system binaries it reaches past the interposition
# directory, how their stand-ins record, and how rows get into the window.
#
# Watchdog is a Python applet; the test files are still POSIX sh, because the
# assertion surface (files, exit codes, recorded window writes, bridge calls) is
# language-neutral.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".

TEST_HELPERS="$OMCTEST_TESTS/helpers"

# API 7 is the floor: this suite reads the window over the remote bridge
# (bridge_called / bridge_value), which nothing before 7 stands up.
[ "${OMCTEST_API_VERSION:-0}" -ge 7 ] || {
    printf 'lib.test.watchdog: needs omctest API 7 or newer, got %s\n' \
        "${OMCTEST_API_VERSION:-none}" >&2
    exit 1
}

# --- View ids, imported from the applet rather than restated -------------------
#
# lib_watchdog.py spells them "ID_EVENT_TABLE = 1" and "COLUMN_PATH = 4", some
# with a trailing comment. Restating the numbers here would let the two lists
# disagree silently; importing them means a renamed constant fails loudly at the
# guard below instead of every check failing one by one with no hint why.
#
# The PB_ line is the same rule for a string: the preview hand-off board is
# named by a prefix the applet and the suite have to agree on exactly, so it is
# read rather than retyped.
eval "$(/usr/bin/sed -n \
    -e 's/^\(ID_[A-Z0-9_]*\) *= *\([0-9][0-9]*\).*$/\1=\2/p' \
    -e 's/^\(COLUMN_[A-Z0-9_]*\) *= *\([0-9][0-9]*\).*$/\1=\2/p' \
    -e 's/^\(PB_[A-Z0-9_]*\) *= *"\([^"]*\)".*$/\1="\2"/p' \
    "$OMCTEST_APP/Contents/Resources/Scripts/lib_watchdog.py")"

[ -n "$ID_EVENT_TABLE" ] && [ -n "$ID_BTN_START" ] && [ -n "$COLUMN_PATH" ] \
    && [ -n "$ID_PREVIEW" ] && [ -n "$PB_PREVIEW_PATH_PREFIX" ] || {
    printf 'lib.test.watchdog: no view ids imported from lib_watchdog.py\n' >&2
    exit 1
}

# The four buttons that act on the selected row. One list, because every
# assertion about them is an assertion about all four together.
SELECTION_BUTTONS="$ID_BTN_REVEAL $ID_BTN_INFO $ID_BTN_COPY $ID_BTN_QUICKLOOK"

# --- Reading the engine's own snapshot back ------------------------------------
#
# omc_control_defaults sets OMC_ACTIONUI_VIEW_<id>_VALUE from the document. The
# id is a variable here, so the name has to be built rather than typed.
view_env_value() { # <view-id>
    eval "printf '%s' \"\${OMC_ACTIONUI_VIEW_${1}_VALUE:-}\""
}

# --- Stand-ins for the binaries the harness cannot reach -----------------------
#
# omctest intercepts tools by rebuilding $OMC_OMC_SUPPORT_PATH. pkill, pgrep,
# open, stat, pbcopy and the embedded Python are named by absolute path, so
# lib_watchdog.py names each through an environment variable and the
# suite points that variable at a recorder. Without those seams these handlers
# would simply be uncovered - and a real pkill under test would signal processes
# belonging to whoever is running the suite.
#
# The fakes and their records live in separate directories on purpose: the
# records are cleared between sections, and clearing them must not delete the
# executables the environment variables still point at.

fakes_dir() { printf '%s' "$OMCTEST_WORK/tool-fakes"; }
record_dir() { printf '%s' "$OMCTEST_WORK/tool-records"; }

# The log of one tool's invocations. Absent until the tool is first called.
tool_log() { printf '%s/%s.log' "$(record_dir)" "$1"; }

# What was piped into a tool, for the tools staged to capture it.
tool_stdin() { # <tool>
    local stdin_file
    stdin_file="$(record_dir)/$1.stdin"
    [ -f "$stdin_file" ] || return 0
    /bin/cat "$stdin_file"
}

# Stage what a tool prints - pgrep answering with a pid, say.
stage_stdout() { # <tool> <text>
    printf '%s\n' "$2" > "$(record_dir)/$1.stdout"
}

stage_exit() { # <tool> <rc>
    printf '%s\n' "$2" > "$(record_dir)/$1.rc"
}

# Ask a tool's stand-in to keep what was piped into it. Off by default: a
# recorder that always drained stdin would block for a tool invoked with the
# test's own stdin still attached.
stage_capture_stdin() { # <tool>
    : > "$(record_dir)/$1.capture_stdin"
}

# Forget every recorded invocation and every staged answer. Call this at the top
# of any section that counts calls or asserts a tool was NOT run - the records
# are cumulative across a file, exactly as the chain history is.
tools_reset() {
    /bin/rm -rf "$(record_dir)"
    /bin/mkdir -p "$(record_dir)"
}

# Point every seam at a copy of record.sh named after the tool it replaces.
install_fakes() {
    /bin/rm -rf "$(fakes_dir)"
    /bin/mkdir -p "$(fakes_dir)"
    tools_reset

    WATCHDOG_TEST_RECORD_DIR="$(record_dir)"
    export WATCHDOG_TEST_RECORD_DIR

    local one_tool
    for one_tool in pkill pgrep open stat pbcopy python; do
        /bin/cp "$TEST_HELPERS/record.sh" "$(fakes_dir)/$one_tool.sh"
        /bin/chmod +x "$(fakes_dir)/$one_tool.sh"
    done

    WATCHDOG_PKILL_TOOL="$(fakes_dir)/pkill.sh"
    WATCHDOG_PGREP_TOOL="$(fakes_dir)/pgrep.sh"
    WATCHDOG_OPEN_TOOL="$(fakes_dir)/open.sh"
    WATCHDOG_STAT_TOOL="$(fakes_dir)/stat.sh"
    WATCHDOG_PBCOPY_TOOL="$(fakes_dir)/pbcopy.sh"
    WATCHDOG_PYTHON="$(fakes_dir)/python.sh"

    export WATCHDOG_PKILL_TOOL WATCHDOG_PGREP_TOOL WATCHDOG_OPEN_TOOL
    export WATCHDOG_STAT_TOOL WATCHDOG_PBCOPY_TOOL
    export WATCHDOG_PYTHON
}

# The --command string the start handler hands watchmedo, as recorded. It is the
# argument after "--command", so it is read positionally out of the block.
recorded_watchmedo_command() {
    local log_file
    log_file="$(tool_log python)"
    [ -f "$log_file" ] || return 0
    /usr/bin/awk '/^--command$/ { getline; print; exit }' "$log_file"
}

# How many times a tool was invoked.
tool_calls() { # <tool>
    local log_file
    log_file="$(tool_log "$1")"
    [ -f "$log_file" ] || { printf '0'; return; }
    # Complete invocations only - see record.sh on why the end marker is what counts.
    /usr/bin/grep -c '^--- end$' "$log_file" | /usr/bin/tr -d ' \n'
}

# Did a tool receive this exact argument? A whole-line match, so an argument is
# never confused with a longer one that merely contains it.
tool_got_arg() { # <tool> <argument> -> yes|no
    local log_file
    log_file="$(tool_log "$1")"
    [ -f "$log_file" ] || { printf 'no'; return; }
    /usr/bin/grep -Fxq -- "$2" "$log_file"
    if [ $? -eq 0 ]; then printf 'yes'; else printf 'no'; fi
}

# The same, for an argument only known by its shape (--patterns=<anything>).
tool_got_arg_like() { # <tool> <extended regex matching a whole argument> -> yes|no
    local log_file
    log_file="$(tool_log "$1")"
    [ -f "$log_file" ] || { printf 'no'; return; }
    /usr/bin/grep -Eq -- "^$2\$" "$log_file"
    if [ $? -eq 0 ]; then printf 'yes'; else printf 'no'; fi
}

# Wait for a backgrounded worker to record itself. The start handler spawns the
# monitor and returns without waiting for it, so the record is not there yet
# when omc_run comes back. Never sleep for this.
wait_for_tool() { # <tool> [timeout, default 5] -> yes|no
    # Waits for a COMPLETE invocation. Watching for the log file to exist would
    # race the recorder: the append redirect creates it before the first argument
    # is written, so the arguments could still be missing when this returns.
    omc_wait_for "/usr/bin/grep -q '^--- end\$' \"$(tool_log "$1")\" 2>/dev/null" "${2:-5}"
    if [ $? -eq 0 ]; then printf 'yes'; else printf 'no'; fi
}

# --- Calling into the applet's own library -------------------------------------
#
# Whole-handler tests are coarse; the rules that are easiest to get wrong -
# escaping a directory name for a pkill pattern, reading a Toggle's boolean -
# live in named functions. Arguments are passed as argv, never interpolated into
# the expression, because the values worth testing are exactly the ones holding
# quotes, backslashes and metacharacters.
wd_eval() { # <python expression over lib_watchdog and args[]> [arg ...]
    local expression="$1"
    shift
    # With python3 -c, sys.argv[0] is "-c", so the expression is argv[1] and the
    # arguments follow it. They are passed as argv rather than interpolated into
    # the expression: the values worth testing here are exactly the ones holding
    # quotes, backslashes and parentheses.
    PYTHONPYCACHEPREFIX="$OMCTEST_WORK/pycache" "$OMCTEST_PYTHON" -c '
import sys, os
sys.path.insert(0, os.path.join(os.environ["OMC_APP_BUNDLE_PATH"],
                                "Contents", "Resources", "Scripts"))
import lib_watchdog
args = sys.argv[2:]
sys.stdout.write(str(eval(sys.argv[1])))
' "$expression" "$@"
}

# --- What the document itself declares -----------------------------------------
#
# An initial enabled/disabled state declared in the JSON is not observable
# through the virtual window: omctest records what HANDLERS write, and a
# document-declared state is written by nobody. It is still a fact the port had
# to preserve from the nib, so it is asserted against the document.
json_declares_disabled() { # <view-id> -> yes|no
    PYTHONPYCACHEPREFIX="$OMCTEST_WORK/pycache" "$OMCTEST_PYTHON" -c '
import json, sys
wanted = int(sys.argv[2])
def walk(node):
    if isinstance(node, dict):
        if node.get("id") == wanted:
            return bool((node.get("properties") or {}).get("disabled"))
        for value in node.values():
            if isinstance(value, (list, dict)):
                found = walk(value)
                if found is not None:
                    return found
    elif isinstance(node, list):
        for child in node:
            found = walk(child)
            if found is not None:
                return found
    return None
result = walk(json.load(open(sys.argv[1])))
sys.stdout.write("yes" if result else "no")
' "$OMCTEST_APP/Contents/Resources/Base.lproj/Watchdog.json" "$1"
}

# --- The preview window's hand-off ---------------------------------------------
#
# Read back through the same pasteboard the handlers use, rather than out of the
# stub's storage: the stub's file layout is the harness's business, and a test
# reaching into it would keep passing after the applet stopped using the tool.
#
# The board is keyed by the EVENT window, which is what the eye button writes
# under and what the preview window's init handler reads through
# $OMC_PARENT_DIALOG_GUID. Both helpers default to the current window, which is
# the event window everywhere they are called.
preview_handoff() { # [event-window-uuid] -> the path the eye button handed over
    "$OMC_OMC_SUPPORT_PATH/pasteboard" \
        "$PB_PREVIEW_PATH_PREFIX${1:-$OMC_ACTIONUI_WINDOW_UUID}" get
}

clear_preview_handoff() { # [event-window-uuid]
    "$OMC_OMC_SUPPORT_PATH/pasteboard" \
        "$PB_PREVIEW_PATH_PREFIX${1:-$OMC_ACTIONUI_WINDOW_UUID}" set ""
}

# --- The bundle itself ---------------------------------------------------------
#
# Only the applet's own resources: Abracode.framework ships nibs for the
# engine's built-in input dialogs, and those are not this applet's to answer for.
# -prune matters: a .nib is a directory holding designable.nib and
# keyedobjects.nib, so without it one nib bundle counts three times.
applet_nib_count() { # -> count of .nib bundles under the applet's Resources
    local _nibs
    _nibs="$(/usr/bin/find "$OMCTEST_APP/Contents/Resources" -name "*.nib" -prune -print 2>/dev/null)"
    printf '%s' "$_nibs" | /usr/bin/grep -c .
}

# NSMainNibFile is the switch the engine reads at launch: named, it takes the
# legacy NSApplicationMain path and the programmatic menu bar is never installed.
# NAMED, not merely present - OMCApplet/main.m branches on the value's length,
# so a key with an empty string is nib-less to the engine. plutil is asked for
# the value rather than grep for the key, so the helper tests what the engine
# tests. A missing key exits non-zero, which is the nib-less answer.
# An unreadable Info.plist answers "yes", not "no": a check that passes because
# it could not look is worse than no check.
info_plist_names_main_nib() { # -> yes|no
    [ -r "$OMCTEST_APP/Contents/Info.plist" ] || { printf 'yes'; return; }
    local _named
    _named="$(/usr/bin/plutil -extract NSMainNibFile raw -o - \
        "$OMCTEST_APP/Contents/Info.plist" 2>/dev/null)"
    [ -n "$_named" ] && printf 'yes' || printf 'no'
}

# --- The watched directory -----------------------------------------------------
#
# Synthesized rather than committed: it is an empty directory, and building it
# here states exactly what the assertions depend on.
make_watch_dir() { # [name, default "Watched"] -> path
    local dir_path="$OMCTEST_WORK/${1:-Watched}"
    /bin/mkdir -p "$dir_path"
    printf '%s' "$dir_path"
}

# --- Rows in the window --------------------------------------------------------
#
# Two virtual windows exist under test, and the event table is written through
# one and read through the other: event.sh feeds rows with omc_dialog_control,
# which the recording stub captures (ui_rows reads those), while the export
# handler reads them over the bridge from the fake ActionUI host. In the running
# app both are the same window - the split is the harness's, not the applet's -
# so seeding for a bridge read has to go over the bridge.
seed_bridge_rows() { # rows as TSV on stdin
    PYTHONPYCACHEPREFIX="$OMCTEST_WORK/pycache" \
        "$OMCTEST_PYTHON" "$TEST_HELPERS/seed_rows.py" "$ID_EVENT_TABLE"
}

# A plausible event row: timestamp, object glyph, event glyph, path - the shape
# event.sh emits.
event_row() { # <path> [timestamp]
    printf '%s\t%s\t%s\t%s' "${2:-2026-09-05 10:11:12.000000000}" "📄" "✏️" "$1"
}

# --- Small readers -------------------------------------------------------------

text_has() { # <haystack> <fixed needle> -> yes|no
    printf '%s' "$1" | /usr/bin/grep -Fq -- "$2"
    if [ $? -eq 0 ]; then printf 'yes'; else printf 'no'; fi
}

file_has() { # <file> <fixed string> -> yes|no
    [ -f "$1" ] || { printf 'no'; return; }
    /usr/bin/grep -Fq -- "$2" "$1"
    if [ $? -eq 0 ]; then printf 'yes'; else printf 'no'; fi
}

line_count() { # <file>
    [ -f "$1" ] || { printf '0'; return; }
    /usr/bin/wc -l < "$1" | /usr/bin/tr -d ' \n'
}

# enabled | disabled | untouched - never collapsing the last two. A handler that
# skipped a control entirely must not read as one that disabled it: that is
# exactly how a control id lost in a port survives unnoticed, and collapsing
# them would also pin the omission, so that adding the missing omc_disable turns
# the test red.
enabled_state() { # <view-id>
    case "$(ui_enabled "$1")" in
        1) printf 'enabled' ;;
        0) printf 'disabled' ;;
        *) printf 'untouched' ;;
    esac
}

# The state shared by all four selection buttons, or "mixed" when they disagree.
selection_buttons_state() {
    local first_state=""
    local one_id
    local one_state
    for one_id in $SELECTION_BUTTONS; do
        one_state="$(enabled_state "$one_id")"
        if [ -z "$first_state" ]; then
            first_state="$one_state"
        elif [ "$one_state" != "$first_state" ]; then
            printf 'mixed'
            return
        fi
    done
    printf '%s' "$first_state"
}

# One hygiene check per file, covering every section above it.
wd_hygiene_check() {
    check "no writes to undeclared view ids" "" "$(ui_unknown_writes)"
    check "no table clobbered by a bare value write" "" "$(ui_suspect_writes)"
    check "no harness misuse" "" "$(ui_errors)"
}

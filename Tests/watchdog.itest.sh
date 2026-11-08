# Tests/watchdog.itest.sh - Watchdog through the real engine (appletbuilder itest, OMC 5.5).
#
# The omctest suites (*.test.sh) run Watchdog's Python handlers one at a time with stand-in tools;
# this file launches the applet itself: the main command on a folder opens the monitor window, its
# INIT_SUBCOMMAND_ID chains to watchdog.monitor.start, a file created in the folder shows up in the
# event table through watchmedo and event.sh, and Export writes the log through the save panel,
# answered by the test. The harness then quits the applet, which runs app.will.terminate
# (WAIT_FOR_TASK_COMPLETION, the checklist's Watchdog line) to stop the monitor. Everything it
# watches and writes is in $ITEST_WORK.

eval "$(/usr/bin/sed -n 's/^\(ID_[A-Z_]*\) *= *\([0-9][0-9]*\).*$/\1=\2/p' \
    "$ITEST_APP/Contents/Resources/Scripts/lib_watchdog.py")"
check "the view ids imported from lib_watchdog.py" "1 13" "$ID_EVENT_TABLE $ID_BTN_EXPORT"

WATCH="$ITEST_WORK/watched"
/bin/mkdir -p "$WATCH"
events() { # <window> -> the event table's rows, as the bridge gives them (JSON)
    itest_call actionui.getRows "{\"window\": \"$1\", \"viewID\": $ID_EVENT_TABLE}"
}
# Waits up to <seconds> for the event table to mention <text>; prints the rows it last saw.
wait_for_event() { # <window> <text> <seconds>
    local _deadline=$(( SECONDS + $3 ))
    local _rows=""
    while [ "$SECONDS" -lt "$_deadline" ]; do
        _rows="$(events "$1")"
        case "$_rows" in
            *"$2"*) break ;;
        esac
        /bin/sleep 0.25
    done
    printf '%s\n' "$_rows"
}

# The monitor's start command never finishes in the engine's eyes: watchmedo, started with Popen
# and not waited for, keeps the handler's output pipes open, so omc.test.status counts it as an
# active command for as long as the monitor runs and the applet is never idle. So the test waits
# for the applet's activity to stop changing instead of for idle.
activity() { itest_call omc.test.status | /usr/bin/sed -n 's/.*"activity": \([0-9]*\).*/\1/p'; }
wait_quiet() { # <seconds>: until the activity count holds for a second; a failed check otherwise
    local _deadline=$(( SECONDS + $1 ))
    local _last="$(activity)"
    local _now=""
    while [ "$SECONDS" -lt "$_deadline" ]; do
        /bin/sleep 1
        _now="$(activity)"
        if [ -n "$_now" ] && [ "$_now" = "$_last" ]; then
            return 0
        fi
        _last="$_now"
    done
    check "the applet settled within ${1}s" "yes" "no"
    return 1
}
# Readiness: watchmedo reports nothing until it is up, and how long that takes depends on the
# machine (its embedded Python loads cold in a freshly signed copy). Create probe files until one
# shows up in the table, instead of guessing a delay.
wait_until_watching() { # <window> <seconds>
    local _deadline=$(( SECONDS + $2 ))
    local _n=0
    while [ "$SECONDS" -lt "$_deadline" ]; do
        _n=$(( _n + 1 ))
        : > "$WATCH/probe-$_n.txt"
        /bin/sleep 0.5
        case "$(events "$1")" in
            *"probe-"*) return 0 ;;
        esac
    done
    return 1
}

section "The main command on a folder opens the monitor, which starts watching"
before="$(itest_windows)"
itest_run Watchdog --file "$WATCH" > /dev/null
wait_quiet 60
window="$(itest_new_window "$before")"
check "the monitor window opened" "yes" "$([ -n "$window" ] && printf yes || printf no)"
wait_until_watching "$window" 30
check "the monitor reports events" "0" "$?"

section "A file created in the folder shows up as an event"
printf 'hello\n' > "$WATCH/itest-created.txt"
rows="$(wait_for_event "$window" "itest-created.txt" 20)"
check_contains "the event table lists the new file" "$WATCH/itest-created.txt" "$rows"

section "Export writes the log where the user chose"
itest_answer_save "$ITEST_WORK/events.tsv"
check "the Export button fires watchdog.export.events" "watchdog.export.events" "$(itest_click "$window" "$ID_BTN_EXPORT")"
wait_quiet 60
check "a save panel" "save" "$(itest_panel last kind)"
check "with the default name from the folder" "watchdog_events_watched.tsv" "$(itest_panel last defaultName)"
check "the log was written" "yes" "$([ -s "$ITEST_WORK/events.tsv" ] && printf yes || printf no)"
check_contains "with the event in it" "itest-created.txt" "$(/bin/cat "$ITEST_WORK/events.tsv" 2>/dev/null)"

section "Quitting stops the monitor"
# app.will.terminate (WAIT_FOR_TASK_COMPLETION) stops watchmedo before the applet exits; the
# harness then sees the applet gone and checks its exit status.
itest_quit
monitors="$(/bin/ps -axo command | /usr/bin/grep -F -- "$WATCH" | /usr/bin/grep -c watchmedo)"
check "no watchmedo is left watching the test's folder" "0" "$monitors"

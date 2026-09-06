#!/bin/sh
# Tests/10-window.test.sh - the window as it opens, and the selection gate.
#
# These are the two things the nib-to-ActionUI port could break without any
# visible symptom: a control id that did not survive the rename writes nowhere
# and says nothing, and a selection gate reading the wrong column simply leaves
# every button live.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".

. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.watchdog.sh"

install_fakes

section "the window's declared defaults"
# This is the window as a user meets it. Starting from omc_reset_controls would
# describe a window where the recursive box is unticked, which no user has seen.
omc_control_defaults Watchdog
check "the document's defaults loaded" "yes" \
    "$([ "${OMCTEST_DEFAULTS_APPLIED:-0}" -ge 2 ] && echo yes || echo no)"
check "recursive starts ticked" "true" "$(view_env_value "$ID_RECURSIVE")"
check "directory events start unticked" "false" "$(view_env_value "$ID_INCLUDE_DIRS")"
check "the watch pattern starts empty" "" "$(view_env_value "$ID_WATCH_PATTERNS")"
check "the ignore pattern starts empty" "" "$(view_env_value "$ID_IGNORE_PATTERNS")"

section "the document declares the at-rest states the nib carried"
# The nib disabled Stop and the four row actions on each buttonCell, which is
# easy to miss when reading the XIB - the first extraction for this port did miss
# it. Declaring them in the document means they are right at first paint, before
# any handler has run.
check "Stop starts disabled" "yes" "$(json_declares_disabled "$ID_BTN_STOP")"
check "Reveal starts disabled" "yes" "$(json_declares_disabled "$ID_BTN_REVEAL")"
check "File info starts disabled" "yes" "$(json_declares_disabled "$ID_BTN_INFO")"
check "Copy starts disabled" "yes" "$(json_declares_disabled "$ID_BTN_COPY")"
check "QuickLook starts disabled" "yes" "$(json_declares_disabled "$ID_BTN_QUICKLOOK")"
# The positive control: Start is the one button that IS live at rest.
check "Start starts enabled" "no" "$(json_declares_disabled "$ID_BTN_START")"

section "the recorder keeps every argument it is given"
# Guards the rest of the suite: /bin/echo swallows an argument that is exactly
# "-n", so a recorder built on it would silently drop one and every assertion
# about that argument would be vacuous.
tools_reset
"$WATCHDOG_PKILL_TOOL" -n "plain" -- "-n"
check "a bare -n survives" "yes" "$(tool_got_arg pkill "-n")"
check "a normal argument survives" "yes" "$(tool_got_arg pkill "plain")"
check "the invocation was counted once" "1" "$(tool_calls pkill)"
tools_reset

section "opening the window"
watch_dir="$(make_watch_dir)"
omc_object "$watch_dir"
chains_reset
omc_run watchdog.monitor.init
check_status "init exits cleanly" 0
# Nothing is selected yet, so the four row actions have nothing to act on. The
# document declares them disabled, as the nib did (on each buttonCell rather
# than the button); init re-asserts it so a re-opened window matches a new one.
check "the row actions start dead" "disabled" "$(selection_buttons_state)"
check "monitoring starts on its own" "1" "$(chain_asked watchdog.monitor.start)"

section "opening the window, through to the monitor running"
# Draining the chain runs what the engine would run next, so this is the whole
# window-open sequence rather than just its first handler.
omc_drain_chain
check "the monitor was launched" "yes" "$(wait_for_tool python)"
check "Start is dead once it is running" "disabled" "$(enabled_state "$ID_BTN_START")"
check "Stop is live once it is running" "enabled" "$(enabled_state "$ID_BTN_STOP")"

section "a row is selected: the row actions come alive"
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_TIME" "2026-09-05 10:11:12.000000000"
omc_run watchdog.monitor.selection.change
check_status "the selection handler exits cleanly" 0
check "the row actions are live" "enabled" "$(selection_buttons_state)"

section "the selection is cleared: the row actions go dead again"
# The positive control above is what makes this one worth having: without it a
# handler that disabled the buttons unconditionally would pass here too.
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_TIME" ""
omc_run watchdog.monitor.selection.change
check_status "the selection handler exits cleanly" 0
check "the row actions are dead" "disabled" "$(selection_buttons_state)"

section "the main command leaves the window alone"
# The window is modeless, so the engine runs the main command at a moment of its
# own choosing. Anything it did to the window would race the init handler.
ui_reset
omc_run Watchdog.main
check_status "the main command exits cleanly" 0
check "it wrote nothing to the window" "0" "$(ui_calls .)"

section "cumulative: nothing was written to a view the window does not declare"
wd_hygiene_check

omctest_end

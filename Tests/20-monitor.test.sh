#!/bin/sh
# Tests/20-monitor.test.sh - starting, stopping and restarting the file monitor.
#
# The monitor is a background worker: the start handler spawns watchmedo and
# returns without waiting for it. What the handler is responsible for is the
# command line it builds and the buttons it flips, and that is what is asserted
# here - the embedded interpreter is a recorder throughout, so no directory is
# ever really watched and no process is ever really signaled.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".

. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.watchdog.sh"

install_fakes
watch_dir="$(make_watch_dir)"

section "start builds the watchmedo command line from the window"
omc_object "$watch_dir"
omc_control_defaults Watchdog
tools_reset
ui_reset
omc_run watchdog.monitor.start
check_status "start exits cleanly" 0
check "the monitor was launched" "yes" "$(wait_for_tool python)"
check "  as a module" "yes" "$(tool_got_arg python "-m")"
check "  the module is watchdog.watchmedo" "yes" "$(tool_got_arg python "watchdog.watchmedo")"
check "  in shell-command mode" "yes" "$(tool_got_arg python "shell-command")"
check "  waiting between events" "yes" "$(tool_got_arg python "--wait")"
check "  recursive, the declared default" "yes" "$(tool_got_arg python "--recursive")"
check "  ignoring directory events, the declared default" "yes" \
    "$(tool_got_arg python "--ignore-directories")"
check "  watching the dropped directory" "yes" "$(tool_got_arg python "$watch_dir")"
check "no watch pattern was passed" "no" "$(tool_got_arg_like python '--patterns=.*')"
check "no ignore pattern was passed" "no" "$(tool_got_arg_like python '--ignore-patterns=.*')"
check "the event list was emptied first" "1" "$(ui_calls omc_table_remove_all_rows)"
check "Start went dead" "disabled" "$(enabled_state "$ID_BTN_START")"
check "Stop came alive" "enabled" "$(enabled_state "$ID_BTN_STOP")"

section "the checkboxes are read as ActionUI booleans, not as 1 and 0"
# An ActionUI Toggle carries a Bool and exports "true"/"false"; the nib checkbox
# it replaced exported "1"/"0". A handler still comparing against "1" would read
# both boxes as off here - dropping --recursive it should keep, and adding
# --ignore-directories it should not - so this section is the one that fails if
# the port's boolean handling regresses.
tools_reset
ui_reset
omc_control_defaults Watchdog
omc_control "$ID_RECURSIVE" "false"
omc_control "$ID_INCLUDE_DIRS" "true"
omc_run watchdog.monitor.start
check "the monitor was launched" "yes" "$(wait_for_tool python)"
check "recursive off drops --recursive" "no" "$(tool_got_arg python "--recursive")"
check "including directories drops --ignore-directories" "no" \
    "$(tool_got_arg python "--ignore-directories")"

section "the filter fields reach the command line"
tools_reset
ui_reset
omc_control_defaults Watchdog
omc_control "$ID_WATCH_PATTERNS" "*.txt;*.rtf"
omc_control "$ID_IGNORE_PATTERNS" "*.tmp"
omc_run watchdog.monitor.start
check "the monitor was launched" "yes" "$(wait_for_tool python)"
check "the watch pattern was passed" "yes" \
    "$(tool_got_arg python "--patterns=*.txt;*.rtf")"
check "the ignore pattern was passed" "yes" \
    "$(tool_got_arg python "--ignore-patterns=*.tmp")"

section "the event script is shell-quoted into watchmedo's command"
# watchmedo runs the --command string through a shell, so an apostrophe anywhere
# in the path to the applet would end the string and the monitor would never
# start. Asserting on shlex.quote directly would prove nothing about the handler -
# it stays green with the handler reverted to bare double quotes - so this drives
# the real handler with a nasty path and reads back the command it actually built.
tools_reset
ui_reset
omc_object "$watch_dir"
omc_control_defaults Watchdog
nasty_script="$OMCTEST_WORK/Bob's Stuff/event.sh"
/bin/mkdir -p "$OMCTEST_WORK/Bob's Stuff"
printf '#!/bin/sh\n' > "$nasty_script"
WATCHDOG_EVENT_SCRIPT="$nasty_script" omc_run watchdog.monitor.start
check "the monitor was launched" "yes" "$(wait_for_tool python)"
built_command="$(recorded_watchmedo_command)"
# The expected spelling is derived from the path, not from the handler, so a
# handler that wrapped it in bare double quotes fails this.
expected_quoted="$(wd_eval '__import__("shlex").quote(args[0])' "$nasty_script")"
check "the path is shell-quoted in the command" "yes" \
    "$(text_has "$built_command" "$expected_quoted")"
# And the proof that it is really shell-safe: a shell can parse it back out.
check "a shell parses the command back to the right path" "$nasty_script" \
    "$(/bin/sh -c "set -- $built_command; echo \"\$2\"" 2>/dev/null)"

section "start refuses anything that is not a directory"
tools_reset
not_a_dir="$OMCTEST_WORK/regular-file.txt"
printf 'not a directory\n' > "$not_a_dir"
omc_object "$not_a_dir"
omc_run watchdog.monitor.start
check_status "start reports failure" 1
check "no monitor was launched" "0" "$(tool_calls python)"

section "start refuses to run with no directory at all"
tools_reset
omc_object ""
omc_run watchdog.monitor.start
check_status "start reports failure" 1
check "no monitor was launched" "0" "$(tool_calls python)"

section "the kill pattern survives a directory name with regex metacharacters"
# The pattern pkill matches on is built from whatever directory the user dropped
# on the app. Unescaped, a folder called "Notes (2024)" builds a pattern that
# matches the wrong process or none at all, and the Stop button silently does
# nothing for that one folder.
check "a parenthesis is escaped" '/tmp/Notes \(2024\)' \
    "$(wd_eval 'lib_watchdog.ere_escape(args[0])' '/tmp/Notes (2024)')"
check "a bracket is escaped" '/tmp/report\[final\]' \
    "$(wd_eval 'lib_watchdog.ere_escape(args[0])' '/tmp/report[final]')"
check "a plain name is left alone" '/tmp/Documents' \
    "$(wd_eval 'lib_watchdog.ere_escape(args[0])' '/tmp/Documents')"
check "the pattern ends in the escaped path, anchored" "True" \
    "$(wd_eval 'lib_watchdog.watchmedo_pattern(args[0]).endswith(lib_watchdog.ere_escape(args[0]) + "$")' '/tmp/Notes (2024)')"
# The anchor is what stops one watched directory's Stop button killing another's
# monitor: /tmp/foo must not match a monitor watching /tmp/foobar.
check "a longer sibling directory does not match" "False" \
    "$(wd_eval '__import__("re").search(lib_watchdog.watchmedo_pattern(args[0]), args[1]) is not None' \
        '/tmp/foo' 'python3 -m watchdog.watchmedo shell-command --wait --command x /tmp/foobar')"
check "the directory it does watch still matches" "True" \
    "$(wd_eval '__import__("re").search(lib_watchdog.watchmedo_pattern(args[0]), args[1]) is not None' \
        '/tmp/foo' 'python3 -m watchdog.watchmedo shell-command --wait --command x /tmp/foo')"

section "stop kills the monitor for this directory and flips the buttons"
tools_reset
ui_reset
omc_object "$watch_dir"
omc_run watchdog.monitor.stop
check_status "stop exits cleanly" 0
check "pkill was asked once" "1" "$(tool_calls pkill)"
check "  restricted to this user" "yes" "$(tool_got_arg pkill "-U")"
check "  matching the full command line" "yes" "$(tool_got_arg pkill "-f")"
check "  with the pattern for this directory" "yes" \
    "$(tool_got_arg pkill "$(wd_eval 'lib_watchdog.watchmedo_pattern(args[0])' "$watch_dir")")"
check "Start came back" "enabled" "$(enabled_state "$ID_BTN_START")"
check "Stop went dead" "disabled" "$(enabled_state "$ID_BTN_STOP")"

section "restart does nothing while no monitor is running"
# pgrep's stand-in answers with nothing, which is how it reports no match.
tools_reset
ui_reset
chains_reset
omc_run watchdog.monitor.restart
check_status "restart exits cleanly" 0
check "it looked for a running monitor" "1" "$(tool_calls pgrep)"
check "nothing was killed" "0" "$(tool_calls pkill)"
check "nothing was started" "0" "$(chain_asked watchdog.monitor.start)"

section "restart stops and re-starts a running monitor"
tools_reset
ui_reset
chains_reset
stage_stdout pgrep "4242"
omc_run watchdog.monitor.restart
check_status "restart exits cleanly" 0
check "the running monitor was killed" "1" "$(tool_calls pkill)"
check "  with the pattern for this directory" "yes" \
    "$(tool_got_arg pkill "$(wd_eval 'lib_watchdog.watchmedo_pattern(args[0])' "$watch_dir")")"
check "and a fresh one was chained" "1" "$(chain_asked watchdog.monitor.start)"

section "closing the window stops the monitor it owned"
tools_reset
ui_reset
omc_run watchdog.monitor.close
check_status "the close handler exits cleanly" 0
check "the monitor was killed" "1" "$(tool_calls pkill)"
check "  with the pattern for this directory" "yes" \
    "$(tool_got_arg pkill "$(wd_eval 'lib_watchdog.watchmedo_pattern(args[0])' "$watch_dir")")"

section "quitting takes every monitor down, whatever it was watching"
tools_reset
omc_run app.will.terminate
check_status "the terminate handler exits cleanly" 0
check "pkill was asked once" "1" "$(tool_calls pkill)"
check "  matching the embedded interpreter rather than one directory" "yes" \
    "$(tool_got_arg pkill "$(wd_eval 'lib_watchdog.ere_escape(__import__("os").path.join(lib_watchdog.APP_BUNDLE, "Contents", "Library", "Python", "bin")) + "/.*"')")"

section "cumulative: nothing was written to a view the window does not declare"
wd_hygiene_check

omctest_end

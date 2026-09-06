#!/bin/sh
# Tests/30-events.test.sh - the actions that operate on the event list.
#
# The export section is the one that exercises the OMC 5.3 remote bridge: it is
# the only handler that has to READ the window rather than be told about it, so
# it asks the ActionUI host directly. Everything else here reads the engine's
# dispatch-time snapshot, which for a click on a selected row is exactly right.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".

. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.watchdog.sh"

install_fakes
watch_dir="$(make_watch_dir)"
omc_object "$watch_dir"

existing_file="$watch_dir/notes.txt"
printf 'a file that still exists\n' > "$existing_file"
missing_file="$watch_dir/deleted.txt"

section "copy puts the whole selected row on the clipboard"
tools_reset
stage_capture_stdin pbcopy
selected_row="$(event_row "$existing_file")"
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_WHOLE_ROW" "$selected_row"
omc_run watchdog.copy.event
check_status "copy exits cleanly" 0
check "pbcopy was run once" "1" "$(tool_calls pbcopy)"
check "  onto the general pasteboard" "yes" "$(tool_got_arg pbcopy "general")"
check "  with the selected row as its input" "$selected_row" "$(tool_stdin pbcopy)"

section "copy with nothing selected copies nothing"
tools_reset
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_WHOLE_ROW" ""
omc_run watchdog.copy.event
check_status "copy exits cleanly" 0
check "pbcopy was not run" "0" "$(tool_calls pbcopy)"

section "reveal opens the selected file in the Finder"
tools_reset
alerts_reset
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_PATH" "$existing_file"
omc_run watchdog.reveal.in.finder
check_status "reveal exits cleanly" 0
check "open was run once" "1" "$(tool_calls open)"
check "  with -R" "yes" "$(tool_got_arg open "-R")"
check "  on the selected file" "yes" "$(tool_got_arg open "$existing_file")"
check "no alert was raised" "0" "$(alerts_count)"

section "reveal on a file that is already gone says so"
# The normal case, not an edge case: a row records an event that has happened,
# and a deleted file is one of the events being recorded.
tools_reset
alerts_reset
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_PATH" "$missing_file"
omc_run watchdog.reveal.in.finder
check_status "reveal exits cleanly" 0
check "the Finder was not opened" "0" "$(tool_calls open)"
check "the user was told" "1" "$(alerts_count)"
check "  and told what was wrong" "1" "$(alerts_mention 'does not exist')"

section "the eye button hands the selected file to the preview window"
# The preview is one of this app's own ActionUI windows now, not a qlmanage
# process, so the handler no longer runs anything. Its whole job is to check the
# file is still there, put the path on the board this window hands off through,
# and chain to the command that carries the preview window.
#
# The board is cleared first, like every other channel a section measures. It
# holds nothing at this point in the file, so the check is live either way - but
# an assertion that reads a channel it did not reset is one bad merge away from
# passing on a value it did not cause.
alerts_reset
chains_reset
clear_preview_handoff
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_PATH" "$existing_file"
omc_run watchdog.quicklook
check_status "the eye button exits cleanly" 0
check "the preview window was asked for" "1" "$(chain_asked watchdog.preview)"
check "  and the selected file was handed over" "$existing_file" "$(preview_handoff)"
check "no alert was raised" "0" "$(alerts_count)"

section "the preview window opens on the file it was handed"
# The init handler runs in the preview window, which has no table to read the
# selection from: the path reaches it only through the board, named by the event
# window that chained here. omc_child_sheet is the harness's word for exactly
# that arrangement - a second window with its own uuid and the originating one
# in $OMC_PARENT_DIALOG_GUID, which is what the engine sets up before it builds
# a dialog. Dispatching in the new window is what makes the assertion mean
# something: omc_dialog_control writes to whatever uuid it is handed, so reading
# the result back through the event window's uuid would pass for a handler
# writing to the wrong window.
omc_child_sheet Preview
ui_reset
omc_run watchdog.preview.init
check_status "the init handler exits cleanly" 0
check "the preview was pointed at the file" "$existing_file" "$(ui_value "$ID_PREVIEW")"
check "and the window took the file's name" "notes.txt" "$(ui_title)"

section "the preview window handed nothing is left alone"
# Not a situation a user can reach - the eye button alerts instead of chaining
# when there is no file - but it decides what a bug looks like, and the handler
# has to pick: an untouched window, or one retitled to "" and pointed at "".
# Counting the writes is what tells those apart. Reading the value back would
# not: a handler that wrote the empty path answers "" exactly as one that wrote
# nothing does, so the obvious assertion here is one that cannot fail.
#
# The alert count is the other half of "left alone", and the handler's docstring
# claims it: blank reads as nothing to see, an alert reads as something broken.
ui_reset
alerts_reset
clear_preview_handoff "$OMC_PARENT_DIALOG_GUID"
omc_run watchdog.preview.init
check_status "the init handler exits cleanly" 0
check "the window was not written to at all" "0" "$(ui_calls .)"
check "and nothing was raised at the user" "0" "$(alerts_count)"

# Back to the event window: everything below reads and writes that one.
omc_leave_sheet

section "the eye button on a file that is already gone says so"
alerts_reset
chains_reset
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_PATH" "$missing_file"
omc_run watchdog.quicklook
check "no preview window was asked for" "0" "$(chain_asked watchdog.preview)"
check "the user was told" "1" "$(alerts_count)"

section "file info runs stat on the selected file"
tools_reset
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_PATH" "$existing_file"
omc_run watchdog.file.info
check_status "file info exits cleanly" 0
check "stat was run once" "1" "$(tool_calls stat)"
check "  in verbose mode" "yes" "$(tool_got_arg stat "-x")"
check "  on the selected file" "yes" "$(tool_got_arg stat "$existing_file")"

section "file info on a file that is already gone reports it instead of running stat"
tools_reset
omc_table_cell "$ID_EVENT_TABLE" "$COLUMN_PATH" "$missing_file"
omc_run watchdog.file.info
check_status "file info exits cleanly" 0
check "stat was not run" "0" "$(tool_calls stat)"
check_grep "the missing file was reported" 'file does not exist' "$OMCTEST_UI/handlers.log"

section "clear empties the event table and stands the row actions down"
# Emptying the table clears the selection in the model but fires no actionID, so
# nothing else would take the row buttons down and they would sit live over a
# selection that no longer exists.
ui_reset
omc_run watchdog.clear.event.list
check_status "clear exits cleanly" 0
check "the table was emptied" "1" "$(ui_calls omc_table_remove_all_rows)"
check "the row actions went dead with it" "disabled" "$(selection_buttons_state)"

section "export canceled writes nothing and reads nothing"
# An empty save-as answer is how OMC reports that the user canceled. This runs
# before the successful export because bridge_called counts from the start of
# the file: asserting zero reads here is only meaningful while it is still zero.
tools_reset
omc_dialog_answer save_as ""
omc_run watchdog.export.events
check_status "export exits cleanly" 0
check "the window was not read" "0" "$(bridge_called actionui.getRows)"

section "export writes every row in the window, read over the bridge"
# The nib build was handed the whole table as $OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS,
# requested through the command's ENVIRONMENT_VARIABLES. That request is silently
# dropped for an ActionUI table, so the ported handler asks the window itself.
export_file="$OMCTEST_WORK/events.tsv"
printf '%s\n%s\n' \
    "$(event_row "$watch_dir/first.txt")" \
    "$(event_row "$watch_dir/second.txt")" | seed_bridge_rows
omc_dialog_answer save_as "$export_file"
omc_run watchdog.export.events
check_status "export exits cleanly" 0
check "the table was read over the bridge" "1" "$(bridge_called actionui.getRows)"
check_exists "the export file was written" "$export_file"
check "it holds one line per row" "2" "$(line_count "$export_file")"
check "  the first row's path survived" "yes" "$(file_has "$export_file" "$watch_dir/first.txt")"
check "  the second row's path survived" "yes" "$(file_has "$export_file" "$watch_dir/second.txt")"
check "  and the columns are still tab-separated" "yes" \
    "$(file_has "$export_file" "$(printf '\t📄\t')")"

section "export tells the user when the window cannot be read"
# omc.OMCError is a RuntimeError; the bridge's own EndpointError is a
# ConnectionError. Catching only the first lets a dead host escape as a
# traceback with nothing said to the user, who then believes the export ran.
alerts_reset
saved_endpoint="$ACTIONUI_REMOTE_ENDPOINT"
ACTIONUI_REMOTE_ENDPOINT="$OMCTEST_WORK/no-such-host.sock"
OMC_ACTIONUI_REMOTE_ENDPOINT="$ACTIONUI_REMOTE_ENDPOINT"
export ACTIONUI_REMOTE_ENDPOINT OMC_ACTIONUI_REMOTE_ENDPOINT
unreachable_out="$OMCTEST_WORK/unreachable.tsv"
omc_dialog_answer save_as "$unreachable_out"
omc_run watchdog.export.events
check_status "export reports failure" 1
check "the user was told" "1" "$(alerts_count)"
check_absent "and no half-written file was left behind" "$unreachable_out"
ACTIONUI_REMOTE_ENDPOINT="$saved_endpoint"
OMC_ACTIONUI_REMOTE_ENDPOINT="$saved_endpoint"
export ACTIONUI_REMOTE_ENDPOINT OMC_ACTIONUI_REMOTE_ENDPOINT

section "export tells the user when the file cannot be written"
alerts_reset
omc_dialog_answer save_as "$OMCTEST_WORK/no-such-directory/events.tsv"
omc_run watchdog.export.events
check_status "export reports failure" 1
check "the user was told" "1" "$(alerts_count)"

section "cumulative: nothing was written to a view the window does not declare"
wd_hygiene_check

omctest_end

#!/bin/bash

# watchmedo tool from watchdog python module invocation:
# ./python3 watchmedo shell-command --recursive --ignore-directories --wait --command='source "path/to/event.sh" "${watch_object}" "${watch_event_type}" "${watch_src_path}" "${watch_dest_path}"' /path/to/dir/to/watch

timestamp=$(/bin/date "+%Y-%m-%d %H:%M:%S.%N")

# echo "[$(/usr/bin/basename "$0")]"

watch_object=$1
watch_event_type=$2
watch_src_path=$3
watch_dest_path=$4

if [ "${watch_object}" = "file" ]; then
    watch_object="📄"
else
    watch_object="📂"
fi

event_row=""
if [ "${watch_event_type}" = "modified" ]; then
    watch_event_type="✏️"
elif [ "${watch_event_type}" = "moved" ]; then
    # we turn move event into two events: move-out and move-in in order to fit in our monitoring list
    event_row="${timestamp}\t${watch_object}\t⬅️\t${watch_src_path}\n${timestamp}\t${watch_object}\t➡️\t${watch_dest_path}"
elif [ "${watch_event_type}" = "created" ]; then
    watch_event_type="❇️"
elif [ "${watch_event_type}" = "deleted" ]; then
    watch_event_type="🗑️"
fi

if [ -z "${event_row}" ]; then
    event_row="${timestamp}\t${watch_object}\t${watch_event_type}\t${watch_src_path}\t${watch_dest_path}"
fi

# echo "${event_row}"

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
echo "${event_row}" | "$dialog_tool" "$OMC_NIB_DLG_GUID" 1 omc_table_add_rows_from_stdin

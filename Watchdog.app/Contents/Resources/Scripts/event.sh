#!/bin/bash

# watchmedo tool from watchdog python module invocation:
# ./python3 watchmedo shell-command --recursive --ignore-directories --wait --command='source "path/to/event.sh" "${watch_object}" "${watch_event_type}" "${watch_src_path}" "${watch_dest_path}"' /path/to/dir/to/watch

timestamp=$(/bin/date "+%H:%M:%S.%N")

watch_object=$1
watch_event_type=$2
watch_src_path=$3
watch_dest_path=$4

if [ "${watch_object}" = "file" ]; then
    watch_object="📄"
else
    watch_object="📂"
fi

if [ "${watch_event_type}" = "modified" ]; then
    watch_event_type="✏️"
elif [ "${watch_event_type}" = "moved" ]; then
    watch_event_type="➡️"
    echo "${timestamp}\t${watch_object}\t⬅️\t${watch_src_path}\n${timestamp}\t${watch_object}\t➡️\t${watch_dest_path}"
    exit 0
elif [ "${watch_event_type}" = "created" ]; then
    watch_event_type="❇️"
elif [ "${watch_event_type}" = "deleted" ]; then
    watch_event_type="🗑️"
fi

echo "${timestamp}\t${watch_object}\t${watch_event_type}\t${watch_src_path}\t${watch_dest_path}"


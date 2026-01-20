#!/bin/bash

echo "[$(/usr/bin/basename "$0")]"

DIR_TO_WATCH=""
if [ -z "${OMC_OBJ_PATH}" ]; then
    echo "Error: directory to monitor not specified"
    exit 1
elif [ -d "${OMC_OBJ_PATH}" ]; then
    DIR_TO_WATCH="${OMC_OBJ_PATH}"
fi

echo "DIR_TO_WATCH: $DIR_TO_WATCH"

PYTHON="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/python3"
echo "PYTHON: $PYTHON"
WATCHMEDO="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/watchmedo"
echo "WATCHMEDO: $WATCHMEDO"

export EVENT_SH="${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/event.sh"
echo "EVENT_SH: $EVENT_SH"

echo "starting watchmedo"

"$PYTHON" "$WATCHMEDO" shell-command \
        --recursive \
        --ignore-directories \
        --wait \
        --command='source "${EVENT_SH}" "${watch_object}" "${watch_event_type}" "${watch_src_path}" "${watch_dest_path}"' "${DIR_TO_WATCH}"

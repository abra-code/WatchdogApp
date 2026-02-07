#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

WATCHMEDO="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/watchmedo"
RUNNING_PID=$(/usr/bin/pgrep -U "${USER}" -f ".* ${WATCHMEDO} shell-command .* ${OMC_OBJ_PATH}$")

echo "RUNNING_PID = ${RUNNING_PID}"

if [ -n "${RUNNING_PID}" ]; then
    source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/watchdog.monitor.stop.sh"
    source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/watchdog.monitor.start.sh"
fi

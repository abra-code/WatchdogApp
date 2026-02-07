#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

# env | sort


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

WATCH_RECURSIVE=""
IS_RECURSIVE="${OMC_NIB_DIALOG_CONTROL_2_VALUE}"
if [ "${IS_RECURSIVE}" = "1" ]; then
    WATCH_RECURSIVE="--recursive"
fi

echo "IS_RECURSIVE = ${IS_RECURSIVE}, WATCH_RECURSIVE = ${WATCH_RECURSIVE}"

WATCH_IGNORE_DIRS=""
IS_INCLUDE_DIRS="${OMC_NIB_DIALOG_CONTROL_3_VALUE}"
if [ "${IS_INCLUDE_DIRS}" != "1" ]; then
    WATCH_IGNORE_DIRS="--ignore-directories"
fi

echo "IS_IGNORE_DIRS = ${IS_IGNORE_DIRS}, WATCH_IGNORE_DIRS = ${WATCH_IGNORE_DIRS}"

WATCH_PATTERNS=""
PATTERN_LIST="${OMC_NIB_DIALOG_CONTROL_4_VALUE}"
if [ -n "${PATTERN_LIST}" ]; then
    WATCH_PATTERNS="--patterns=${PATTERN_LIST}"
fi

echo "PATTERN_LIST = ${PATTERN_LIST}, WATCH_PATTERNS = ${WATCH_PATTERNS}"


WATCH_IGNORE_PATTERNS=""
IGNORE_PATTERN_LIST="${OMC_NIB_DIALOG_CONTROL_5_VALUE}"
if [ -n "${IGNORE_PATTERN_LIST}" ]; then
    WATCH_IGNORE_PATTERNS="--ignore-patterns=${IGNORE_PATTERN_LIST}"
fi

echo "IGNORE_PATTERN_LIST = ${IGNORE_PATTERN_LIST}, WATCH_IGNORE_PATTERNS = ${WATCH_IGNORE_PATTERNS}"

# Clear all rows from the table view (control ID 1)
dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
"$dialog_tool" "$OMC_NIB_DLG_GUID" 1 omc_table_remove_all_rows

echo "starting watchmedo"

echo "$PYTHON $WATCHMEDO shell-command ${WATCH_RECURSIVE} ${WATCH_IGNORE_DIRS} ${WATCH_PATTERNS} ${WATCH_IGNORE_PATTERNS} --wait --command='...' ${DIR_TO_WATCH} &"

"$PYTHON" "$WATCHMEDO" shell-command \
        ${WATCH_RECURSIVE} \
        ${WATCH_IGNORE_DIRS} \
        ${WATCH_PATTERNS} \
        ${WATCH_IGNORE_PATTERNS} \
        --wait \
        --command='source "${EVENT_SH}" "${watch_object}" "${watch_event_type}" "${watch_src_path}" "${watch_dest_path}"' "${DIR_TO_WATCH}" &

start_status=$?
echo "start_status = ${start_status}"

start_button_id="6"
stop_button_id="7"
"$dialog_tool" "$OMC_NIB_DLG_GUID" "$start_button_id" omc_disable
"$dialog_tool" "$OMC_NIB_DLG_GUID" "$stop_button_id" omc_enable

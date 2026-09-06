#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

# env | sort

# column 4 in events table is the path
FILE_EVENT_PATHS="${OMC_NIB_TABLE_1_COLUMN_4_VALUE}"

FILE_REVEALED=0
# just reveal the first existing path
while IFS= read -r one_path; do
    if [ -e "${one_path}" ]; then
        /usr/bin/open -R "${one_path}"
        FILE_REVEALED=1
        break
    fi
done <<< "$FILE_EVENT_PATHS"

if [ "${FILE_REVEALED}" = 0 ]; then
    alert="$OMC_OMC_SUPPORT_PATH/alert"
    "${alert}" --level caution --title "Watchdog" "File does not exist"
fi

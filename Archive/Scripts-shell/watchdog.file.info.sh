#!/bin/sh

# echo "[$(/usr/bin/basename "$0")]"

# env | sort

# column 4 in events table is the path
FILE_EVENT_PATHS="${OMC_NIB_TABLE_1_COLUMN_4_VALUE}"

echo ""
echo "---------------------------------"

while IFS= read -r one_path; do
    if [ -e "${one_path}" ]; then
        /usr/bin/stat -x "${one_path}"
    else
        echo "  File: \"${one_path}\""
        echo "  Status: file does not exist"
    fi
    echo "---------------------------------"
done <<< "$FILE_EVENT_PATHS"

echo ""

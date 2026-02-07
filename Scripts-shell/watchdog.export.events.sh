#!/bin/bash

# Export events from table view to TSV file
echo "[$(/usr/bin/basename "$0")]"
# env | sort

# Check if save path was selected
if [ -z "${OMC_DLG_SAVE_AS_PATH}" ]; then
    echo "Export canceled by user"
    exit 0
fi

echo "Exporting events to: ${OMC_DLG_SAVE_AS_PATH}"

# echo "-------------------------------------"
# echo "OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS:"
# echo "${OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS}"
# echo "-------------------------------------"


# Export all rows from table view 1 to the save path
echo "${OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS}" > "${OMC_DLG_SAVE_AS_PATH}"

# row_count=$(/usr/bin/wc -l "${OMC_DLG_SAVE_AS_PATH}")
# 
# echo "Exported ${row_count} rows to ${OMC_DLG_SAVE_AS_PATH}"

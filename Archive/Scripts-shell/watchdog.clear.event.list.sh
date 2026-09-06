#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

# Clear all rows from the table view (control ID 1)
dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
"$dialog_tool" "$OMC_NIB_DLG_GUID" 1 omc_table_remove_all_rows

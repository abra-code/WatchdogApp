#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

# env | sort

reveal_button_id="8"
info_button_id="9"
copy_button_id="10"

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"

enable_disable="omc_disable"
if [ -n "${OMC_NIB_TABLE_1_COLUMN_1_VALUE}" ]; then
    enable_disable="omc_enable"
fi

"${dialog_tool}" "${OMC_NIB_DLG_GUID}" "${reveal_button_id}" "${enable_disable}"
"${dialog_tool}" "${OMC_NIB_DLG_GUID}" "${info_button_id}" "${enable_disable}"
"${dialog_tool}" "${OMC_NIB_DLG_GUID}" "${copy_button_id}" "${enable_disable}"

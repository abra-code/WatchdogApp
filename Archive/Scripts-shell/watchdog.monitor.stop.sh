#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

# env | sort
WATCHMEDO="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/watchmedo"
/usr/bin/pkill -U "${USER}" -f ".* ${WATCHMEDO} shell-command .* ${OMC_OBJ_PATH}$"

start_button_id="6"
stop_button_id="7"
dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
"$dialog_tool" "$OMC_NIB_DLG_GUID" "$start_button_id" omc_enable
"$dialog_tool" "$OMC_NIB_DLG_GUID" "$stop_button_id" omc_disable

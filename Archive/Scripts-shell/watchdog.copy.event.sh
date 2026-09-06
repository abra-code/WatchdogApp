#!/bin/bash

# Export events from table view to TSV file
echo "[$(/usr/bin/basename "$0")]"
env | sort

export LANG="en_US.UTF-8"
echo "${OMC_NIB_TABLE_1_COLUMN_0_VALUE}" | /usr/bin/pbcopy -pboard general

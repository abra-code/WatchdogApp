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

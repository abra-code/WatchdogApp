#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

# On termination stop all Python processes started by our app
PYTHON_BIN="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/"

/usr/bin/pkill -U "${USER}" -f "${PYTHON_BIN}.*"

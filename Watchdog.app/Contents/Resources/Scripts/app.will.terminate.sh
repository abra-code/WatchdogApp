#!/bin/sh

echo "[$(/usr/bin/basename "$0")]"

# On termination stop all Python processes started by our app
/usr/bin/pkill -f ".*/Watchdog.app/Contents/Library/Python/bin/.*"

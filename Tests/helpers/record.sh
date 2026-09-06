#!/bin/sh
# A stand-in for a system binary the suite must not really run.
#
# Copied once per tool under the tool's own name, so the record file is named
# after the tool that was called. Every invocation appends a block:
#
#     --- invocation
#     <arg 1>
#     <arg 2>
#     --- end
#
# The trailing marker is what makes an invocation observable atomically: the
# append redirect creates the file before the first argument is written, so a
# waiter watching for the file's existence can read a block that is not there
# yet. Counting and waiting both key on "--- end".
#
# One argument per line, because the arguments that matter here are paths and
# glob patterns containing spaces - a space-joined line could not be asserted on
# without ambiguity.
#
# Three optional files stage behavior, each named after the tool:
#   <tool>.stdout          printed verbatim (pgrep answering with a pid)
#   <tool>.rc              used as the exit status
#   <tool>.capture_stdin   drain stdin into <tool>.stdin
#
# Draining stdin is opt-in because a tool invoked with the test's own stdin
# still attached would block forever waiting on it.
#
# POSIX sh only.

tool_name=$(/usr/bin/basename "$0")
tool_name=${tool_name%.sh}

record_dir="${WATCHDOG_TEST_RECORD_DIR:?record.sh needs WATCHDOG_TEST_RECORD_DIR}"

{
    /bin/echo "--- invocation"
    for one_arg in "$@"; do
        printf '%s\n' "$one_arg"
    done
    /bin/echo "--- end"
} >> "$record_dir/$tool_name.log"

if [ -f "$record_dir/$tool_name.capture_stdin" ]; then
    /bin/cat >> "$record_dir/$tool_name.stdin"
fi

if [ -f "$record_dir/$tool_name.stdout" ]; then
    /bin/cat "$record_dir/$tool_name.stdout"
fi

if [ -f "$record_dir/$tool_name.rc" ]; then
    exit "$(/bin/cat "$record_dir/$tool_name.rc")"
fi

exit 0

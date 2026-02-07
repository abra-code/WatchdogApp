#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

THIN_PYTHON_SCRIPT="$SCRIPT_DIR/../Python-Embedding/thin_python_distribution.sh"
if [ ! -f "$THIN_PYTHON_SCRIPT" ]; then
    echo "Error: thin_python_distribution.sh not found at: $THIN_PYTHON_SCRIPT"
    echo "Please fetch Python-Embedding from: https://github.com/abra-code/Python-Embedding"
    exit 1
fi

PYTHON_DIR="$SCRIPT_DIR/Watchdog.app/Contents/Library/Python"
if [ ! -d "$PYTHON_DIR" ]; then
    echo "Error: Python distribution not found at: $PYTHON_DIR"
    echo "Please ensure Watchdog.app bundle exists in the current directory."
    exit 1
fi

# Phase 1: Remove most unused modules
echo
echo "Removing most unused modules..."
"$THIN_PYTHON_SCRIPT" \
  "$PYTHON_DIR" \
  ssl hashlib sqlite3 curses xml dbm decimal ctypes multiprocessing unittest xmlrpc pip setuptools certifi include pyc codecs_east_asian delocate

# Phase 2: Remove additional build tools and unused dependencies
echo
echo "Removing additional build tools and unused dependencies..."
"$THIN_PYTHON_SCRIPT" \
  "$PYTHON_DIR" \
  altgraph macholib packaging regex typing_extensions asyncio requests urllib3 idna charset_normalizer pydoc email html http wsgiref zipfile tomllib lsprof statistics

# Phase 3: Remove .dist-info metadata directories (not needed at runtime)
echo
echo "Removing .dist-info directories..."
/usr/bin/find "$PYTHON_DIR" -type d -name "*-*.dist-info" -exec /bin/rm -rf {} +

echo
echo "Done."
echo

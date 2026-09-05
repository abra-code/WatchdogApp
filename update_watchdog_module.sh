#!/bin/bash
# install_watchdog.sh - (re)install the universal `watchdog` module into Watchdog.app's
# Packages directory, kept separate from the embedded Python runtime.
#
# Why a separate Packages dir (Contents/Library/Packages):
#   - OMC prepends it to PYTHONPATH for every command the applet runs, so `import
#     watchdog` and `python3 -m watchdog.watchmedo` resolve without touching the runtime.
#   - AppletBuilder replaces Contents/Library/Python wholesale when it refreshes or
#     upgrades the embedded Python, wiping anything installed inside it. Packages/ is
#     never touched, so the module survives a Python rebuild.
#   - The applet invokes watchmedo as `python3 -m watchdog.watchmedo`, so only the
#     module needs to be importable - no dependency on a launcher path/shebang.
#
# Run this AFTER building the applet (it needs the embedded Python's pip) and BEFORE
# thin_watchdog.sh (which removes pip). Re-running is safe: it force-reinstalls.
#
# Usage:
#   ./install_watchdog.sh [/path/to/Watchdog.app]
# Defaults to ./Watchdog.app next to this script.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="${1:-$SCRIPT_DIR/Watchdog.app}"

PY="$APP/Contents/Library/Python/bin/python3"
PACKAGES="$APP/Contents/Library/Packages"
MODULE="watchdog"

if [ ! -x "$PY" ]; then
    echo "Error: embedded Python not found at: $PY"
    echo "Build Watchdog.app with embedded Python first (AppletBuilder)."
    exit 1
fi

if ! "$PY" -m pip --version >/dev/null 2>&1; then
    echo "Error: the embedded Python has no pip (already thinned?)."
    echo "Rebuild the applet's Python, then run this before thin_watchdog.sh."
    exit 1
fi

echo "App:     $APP"
echo "Python:  $("$PY" --version 2>&1)  ($PY)"
echo "Target:  $PACKAGES"
echo

# Detect whether the embedded interpreter is a universal (fat) binary. If so, build
# universal wheels from source so the applet runs on both Apple Silicon and Intel.
LIBPY=$(/usr/bin/find "$APP/Contents/Library/Python/lib" -maxdepth 1 -name 'libpython3*.dylib' -print -quit 2>/dev/null)
IS_UNIVERSAL=0
if [ -n "$LIBPY" ] && /usr/bin/lipo -info "$LIBPY" 2>/dev/null | /usr/bin/grep -q "Architectures in the fat file"; then
    IS_UNIVERSAL=1
fi

export PYTHONPYCACHEPREFIX=/tmp/Pyc
/bin/mkdir -p "$PACKAGES"

TRUSTED="--trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org"

echo "Installing $MODULE into Packages/ ..."
if [ "$IS_UNIVERSAL" -eq 1 ]; then
    echo "  embedded Python is universal -> installing universal watchdog (x86_64 + arm64)"
    # pip prefers an official universal2 wheel when one exists (watchdog ships one for
    # recent CPython). Where it doesn't, --no-binary forces a from-source build, and
    # ARCHFLAGS + arch -x86_64 (Rosetta on Apple Silicon) make that build produce fat
    # binaries. The lipo check below enforces the result is actually universal.
    ARCHFLAGS="-arch x86_64 -arch arm64" /usr/bin/arch -x86_64 \
        "$PY" -m pip install --upgrade --force-reinstall --no-binary :all: \
        --target "$PACKAGES" $TRUSTED "$MODULE"
    rc=$?
else
    echo "  embedded Python is single-arch -> installing a matching wheel"
    "$PY" -m pip install --upgrade --force-reinstall \
        --target "$PACKAGES" $TRUSTED "$MODULE"
    rc=$?
fi

if [ "$rc" -ne 0 ]; then
    echo "Error: pip install failed (exit $rc)."
    exit 1
fi

# Strip bytecode pip may have generated (keeps the bundle lean; .pyc files would also
# bake absolute source paths). The runtime regenerates .pyc under PYTHONPYCACHEPREFIX.
/usr/bin/find "$PACKAGES" -type d -name "__pycache__" -exec /bin/rm -rf {} + 2>/dev/null
/usr/bin/find "$PACKAGES" -name "*.py[co]" -delete 2>/dev/null

echo
echo "Verifying ..."

# C extension architecture: require it to be present, and fat when the interpreter is.
EXT=$(/usr/bin/find "$PACKAGES" -maxdepth 1 -name '_watchdog_fsevents*.so' -print -quit 2>/dev/null)
if [ -z "$EXT" ]; then
    echo "  ERROR: _watchdog_fsevents*.so not found in Packages/."
    exit 1
fi
ARCHS=$(/usr/bin/lipo -info "$EXT" 2>&1)
echo "  $ARCHS"
if [ "$IS_UNIVERSAL" -eq 1 ]; then
    if ! echo "$ARCHS" | /usr/bin/grep -q "x86_64" || ! echo "$ARCHS" | /usr/bin/grep -q "arm64"; then
        echo "  ERROR: embedded Python is universal but the watchdog C extension is not"
        echo "         (need both x86_64 and arm64). Retry on a Mac with Rosetta + Xcode"
        echo "         command line tools installed."
        exit 1
    fi
fi

# Import must resolve from Packages/ (PYTHONPATH entries precede the runtime's own
# site-packages), and the watchmedo CLI module must be runnable.
if ! PYTHONPATH="$PACKAGES" "$PY" - "$PACKAGES" <<'PYEOF'
import os, sys
import watchdog
loc = os.path.realpath(os.path.dirname(watchdog.__file__))
target = os.path.realpath(sys.argv[1])
assert loc.startswith(target), "watchdog loaded from %s, not %s" % (loc, target)
import watchdog.watchmedo  # the CLI entry module the applet runs
print("  import watchdog from:", loc)
PYEOF
then
    echo "  ERROR: watchdog did not import from Packages/ (or watchmedo is missing)."
    exit 1
fi

if PYTHONPATH="$PACKAGES" "$PY" -m watchdog.watchmedo --help >/dev/null 2>&1; then
    echo "  python3 -m watchdog.watchmedo: OK"
else
    echo "  ERROR: 'python3 -m watchdog.watchmedo' failed to run from Packages/."
    exit 1
fi

echo
echo "Done. watchdog installed in: $PACKAGES"
echo "The applet invokes it as: \"\$PYTHON\" -m watchdog.watchmedo  (PYTHONPATH set by OMC)."

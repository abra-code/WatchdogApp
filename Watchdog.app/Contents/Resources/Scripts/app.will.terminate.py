#!/usr/bin/env python3

import os
import subprocess
import sys

script_name = os.path.basename(sys.argv[0])
print(f"[{script_name}]")

python_bin = os.path.join(
    os.environ.get("OMC_APP_BUNDLE_PATH", ""),
    "Contents",
    "Library",
    "Python",
    "bin"
)

subprocess.run(
    ["/usr/bin/pkill", "-U", os.environ.get("USER", ""), "-f", f"{python_bin}/.*"]
)

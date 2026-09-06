"""The app is quitting - take every monitor it started down with it.

Matching on the embedded interpreter's own bin directory catches each running
watchmedo whatever directory it was watching, including windows whose close
handler never ran. pkill does not signal itself, and the handler's own
interpreter is going away with the app in any case.
"""

import os
import subprocess

import lib_watchdog as wd

python_bin = os.path.join(wd.APP_BUNDLE, "Contents", "Library", "Python", "bin")

subprocess.run(
    [
        wd.PKILL_TOOL,
        "-U",
        os.environ.get("USER", ""),
        "-f",
        f"{wd.ere_escape(python_bin)}/.*",
    ]
)

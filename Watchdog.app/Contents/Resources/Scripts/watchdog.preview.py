"""watchdog.preview - the command that carries the preview window.

Opening the window is the whole effect of this command; ACTIONUI_WINDOW in
Command.json does that, and watchdog.preview.init points the window at a file.
A non-blocking window's main script runs at a moment OMC chooses, so there is
nothing this one can safely do.
"""

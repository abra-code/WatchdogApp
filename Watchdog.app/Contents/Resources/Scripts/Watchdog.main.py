"""The applet's main command.

The window is modeless (IS_BLOCKING false), so the engine runs this at a moment
of its own choosing - before, during or after the window appears. Anything that
touches the window therefore belongs in the init subcommand
(watchdog.monitor.init), which is guaranteed to run while the window is being
set up. This handler exists so the command has a body, and does nothing else.
"""

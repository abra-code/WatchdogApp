"""Track the event table's selection and gate the four row actions on it."""

import lib_watchdog as wd

# Every real row carries a timestamp, so a value in column 1 means a row is
# selected and an empty one means the selection was cleared.
has_selection = wd.table_value(wd.COLUMN_TIME) != ""

wd.set_enabled_many(wd.SELECTION_BUTTON_IDS, has_selection)

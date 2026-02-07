# Building Watchdog.app

## Step-by-step guide how Watchdog.app is created.

### Step 1: Basic Python applet
Clone [OMC](https://github.com/abra-code/OMC/) at `~/git/OMC/`<br>
Set up new git repo at `~/git/WatchdogApp/`

.gitignore is set up to exclude the large binary files at:
```
Watchdog.app/Contents/
    Frameworks/Abracode.framework (core OMC engine)
    Library/Python/ (relocatable Universal Python distribution)
    MacOS/Watchdog (app binary executable)
    _CodeSignature/ (generated codesigning files)
```
These excluded files are NOT present in the repo but are created locally when following the build steps.

Watchdog.icon was created using [Icon Composer.app](https://developer.apple.com/icon-composer/) and placed in `~/git/WatchdogApp/Icon/`

Download the latest [OMC release](https://github.com/abra-code/OMC/releases). You will need OMCPythonApplet.app from there.

We create a new applet by using `~/git/OMC/build_applet.sh` and pointing to OMCPythonApplet.app template.<br>
`build_applet.sh` requires Xcode.app or Xcode command line tool installation. It should prompt for it if not present on your Mac.

OMCPythonApplet is much bigger than regular OMCApplet but we are going to utilize "watchdog" Python module for the core functionality.
The Python applet comes with with an embedded relocatable Python 3.x distribution as Universal binary, containing executables for both arm64 for Apple Silicon Macs and x86_64 for Intel Macs.

```
cd ~/git
./OMC/build_applet.sh --verbose \
                      --omc-applet="OMC_4.4.0/Products/Applications/OMCPythonApplet.app" \
                      --icon="WatchdogApp/Icon/Watchdog.icon" \
                      --bundle-id=com.abracode.watchdog \
                      --creator=WDog \
                      WatchdogApp/Watchdog.app
```

Next step is codesigning for local execution:
```
./OMC/codesign_applet.sh "WatchdogApp/Watchdog.app"
```

At this point we have the basic running app with "Hello World" functionality executing "Welcome.main.py" script at app launch.


### Step 2: Installing Python "watchdog" module

Change working directory to operate inside embedded Python module and verify it works:
```
cd ~/git/WatchdogApp/Watchdog.app/Contents/Library/Python/bin
export PYTHONPYCACHEPREFIX=/tmp/Pyc
./python3 --help
```
If you are on Apple Silicon Mac, run the following command to build and install Universal "watchdog" module:
```
export ARCHFLAGS="-arch x86_64 -arch arm64"
arch -x86_64 ./python3 -m pip install --verbose --force-reinstall --no-binary :all: watchdog

```
Note: `arch -x86_64` executes the binary under Rosetta emulation. This builds universal binaries with ARCHFLAGS as above on my Apple Silicon Mac. When running without `arch -x86_64` I ended up with single arm64 architecture for some reason. If the build succeeds you will see 'watchmedo' tool in Python/bin.
Verify the properly built universal binary with:
```
lipo -info ../lib/python3.*/site-packages/*_watchdog_fsevents*.so
```
You should see the result like:
`Architectures in the fat file: ../lib/python3.14/site-packages/_watchdog_fsevents.cpython-314-darwin.so are: x86_64 arm64 `<br>
Now we are ready to try `watchmedo` tool:
```
./python3 watchmedo --help
./python3 watchmedo log --help
./python3 watchmedo log --verbose --recursive ~/Downloads
```
After running the above command the `watchmedo` tool enters a runloop observing `~/Downloads` and waiting for something to happen there. Add or remove a file. modify some text and see the file events begin reported by `watchmedo` in Terminal.

Next, let's create an `event.sh` script to be executed by `watchmedo shell-command event.sh`. See `./python3 watchmedo shell-command --help` for details. This allows us execute our own script for each received file event.
We are going to place `event.sh` in:
`~/git/WatchdogApp/Watchdog.app/Contents/Resources/Scripts/`

Now test monitoring "Downloads" folder with our custom "event.sh" script:

```
./python3 watchmedo shell-command --recursive --ignore-directories --wait --command='source "../../../Resources/Scripts/event.sh" "${watch_object}" "${watch_event_type}" "${watch_src_path}" "${watch_dest_path}"' $HOME/Downloads
```

Saving a new test.txt file in Downloads folder with BBEdit produces something like:
```

01:35:52.620851000	📄	✏️	/Users/papasmurf/Downloads/.DS_Store	
01:35:59.409851000	📄	❇️	/Users/papasmurf/Downloads/test.txt	
01:35:59.421107000	📄	✏️	/Users/papasmurf/Downloads/test.txt	
```

Our `event.sh` reformats the printed output to produce tab-separated content containing timestamps and translating files/dirs into emoji, also presenting the event as an emoji.



### Step 3: Adding starting point in Watchdog.app

In order to start `watchmedo` inside Watchdog.app we need to create a command description with script handler and declare it in Command.plist.<br>
We rename template "Welcome" command to "Watchdog", which will be our primary command group. The first command in the group has no COMMAND_ID and with `EXECUTION_MODE=exe_script_file` OMC engine will look for "Resources/Scripts/Watchdog.main.sh" to execute.<br>
We choose the following settings for the main command:<br>
`ACTIVATION_MODE=act_folder` - we only process directories<br>
`ENVIRONMENT_VARIABLES={OMC_OBJ_PATH=''}` - we tell the OMC engine the script always needs object path (object being directory in our case). This step is not needed in OMC 4.4 because act_folder implies OMC_OBJ_PATH is required.<br>
With these 2 settings for the main command, the applet behavior is as follows:
- when launched without any folder, applet prompts to select a folder
- when "Watchdog" command is selected from "Commands" menu, it asks to select a folder
- you may drop a folder on Watchdog.app icon to trigger the main command with that dir path as context.<br>

We set `EXECUTION_MODE=exe_script_file_with_output_window` to see the output. This is temporary for debugging so we can verify the setup works as expected. The same can be achieved for `EXECUTION_MODE=exe_script_file` by holding "control" keyboard modifier: the  window will capture the command stdout prints.

Long-running process like `watchmedo` with its own runloop is not usual for shell script applets. In most cases the command handlers are single shot quick scripts, returning control to the app. In our case we have a background process waiting for file system events and it does not terminate even if the parent app quits. In order to ensure we have no orphaned observers we should terminate the ones we started. One simple way to do it is to handle special `COMMAND_ID=app.will.terminate` which is triggered on applet quit and kill all python3 processes started from `Watchdog.app/Contents/Library/Python/bin/`. Note that this code makes simplistic assumption that there is only one instance of Watchdog.app running at the same time - which is good enough in 99% of cases.

### Step 4: Creating a new window nib
In order to have a user friendly interface we will need to present a window (or a "dialog" in classic terminology). OMC engine currently supports loading windows/dialogs from nib files.<br>
Let's create a new window in Xcode: File -> New -> File from Template... -> macOS -> User Interface -> Window, it creates a new .xib file. Let's save it as `WatchdogMonitor.xib`.<br>

At this point we need to understand different nib and xib formats. The default .xib file created by Xcode is a flat (non-bundled) editable Interface Builder file. It is not loadable at runtime by the app. It needs to be compiled into a loadable .nib file. In normal Xcode app projects when you build the app, Xcode compiles .xib and places a .nib in the app bundle's resources. However, the .nib compiled by Xcode into the app bundle is no longer editable. It is a flat file with editing info stripped. Because we are doing the OMC applet development mostly outside of Xcode and don't maintain an xcodeproj building an app, the setup with editing a xib and then compiling manually to a flat, non-editable nib is not an appealing workflow. It is doable but it is cumbersome. Luckily there is a better solution. There is a bundled .nib format which contains both a file with editable information and a loadable file. When we create a new .xib in Xcode we can convert it once to .nib bundle with:
```
/usr/bin/xcrun ibtool --compile WatchdogMonitor.nib --flatten NO WatchdogMonitor.xib

# the content of .nib bundle:
WatchdogMonitor.nib:
    designable.nib <-- editable and readable xml
    keyedobjects.nib <-- loadable compiled binary stream
```

Such nib can be placed directly in the applet and edited right from there:
`Watchdog.app/Contents/Resources/Base.lproj/WatchdogMonitor.nib`
Double-clicking such .nib opens it in Xcode and each change is saved in editable designable.nib xml **and** compiled into keyedobjects.nib loadable binary.
That way the applet content **is** our project - there are no files outside of it and we are editing Command.plist, scripts and .nibs in-place.

Now let's extend the "Watchdog" command description to display the WatchdogMonitor window:

```
		<dict>
			<key>NAME</key>
			<string>Watchdog</string>
			...
			<key>NIB_DIALOG</key>
			<dict>
				<key>NIB_NAME</key>
				<string>WatchdogMonitor</string>
				<key>IS_BLOCKING</key>
				<false/>
				<key>INIT_SUBCOMMAND_ID</key>
				<string>watchdog.monitor.init</string>
				<key>END_CANCEL_SUBCOMMAND_ID</key>
				<string>watchdog.monitor.close</string>
			</dict>
		</dict>
```

We add `NIB_DIALOG` dictionary with `NIB_NAME` pointing to our file (no .nib extension). We make it non-modal with `IS_BLOCKING=false`. 
This alone is enough to display the window when the command is executed but we need to add two dialog handlers to run code when the window opens and when it is closed.
`INIT_SUBCOMMAND_ID=watchdog.monitor.init` tells the OMC engine to run `watchdog.monitor.init` command on window initialization and `END_CANCEL_SUBCOMMAND_ID=watchdog.monitor.close` is called when dialog is canceled with "Cancel" button or closed with the window's close button (we will not have a "Cancel" button in our UI).

Since we referenced two new commands in WatchdogMonitor dialog, we need to add them to the Command.plist:

```
		<dict>
			<key>NAME</key>
			<string>Watchdog</string>
			<key>COMMAND_ID</key>
			<string>watchdog.monitor.init</string>
			<key>EXECUTION_MODE</key>
			<string>exe_script_file</string>
		</dict>
		<dict>
			<key>NAME</key>
			<string>Watchdog</string>
			<key>COMMAND_ID</key>
			<string>watchdog.monitor.close</string>
			<key>EXECUTION_MODE</key>
			<string>exe_script_file</string>
		</dict>
```

We declare `EXECUTION_MODE=exe_script_file` so with `COMMAND_ID=watchdog.monitor.init` OMC engine will run the script file of the same name in `Watchdog.app/Contents/Resources/Scripts/` (with appropriate extension)

Finally, we add the placeholder script files. We are picking Python for this example to exercise the embedded Python runtime. They could also be shell .sh files.

```
Resources/Scripts/watchdog.monitor.init.py
Resources/Scripts/watchdog.monitor.close.py
```

The new placeholder files have this content, which prints the script name and the sorted environment variables:

```
import sys
import os

script_path = sys.argv[0]
script_name = os.path.basename(script_path)
print(script_name)

for name in sorted(os.environ):
    print(f"{name: <32} = {os.environ[name]}")
```

Printing environment variables will help us understand which variables are set up by OMC engine upon script execution in any given context. Again, in order to see the output you need to hold "control" key when the command is starting. Or temporarily set `EXECUTION_MODE=exe_script_file_with_output_window` for initial debugging.

Let's take a look at the env variables provided when executing `watchdog.monitor.init.py` script (uninteresting standard env variables snipped):

```
watchdog.monitor.init.py

OMC_APP_BUNDLE_PATH      = /Users/papasmurf/git/WatchdogApp/Watchdog.app
OMC_CURRENT_COMMAND_GUID = 0253D99B-3714-425E-97E5-334EB64FE102
OMC_NIB_DLG_GUID         = D7AAA4E4-9159-4EB1-BBEF-58044983890D
OMC_OBJ_PATH             = /Users/papasmurf/Downloads
OMC_OMC_RESOURCES_PATH   = /Users/papasmurf/git/WatchdogApp/Watchdog.app/Contents/Frameworks/Abracode.framework/Resources
OMC_OMC_SUPPORT_PATH     = /Users/papasmurf/git/WatchdogApp/Watchdog.app/Contents/Frameworks/Abracode.framework/Versions/Current/Support
PATH                     = /Users/papasmurf/git/WatchdogApp/Watchdog.app/Contents/Library/Python/bin:/usr/bin:/bin:/usr/sbin:/sbin
PYTHONPYCACHEPREFIX      = /tmp/Pyc
```
1. Python applet sets `PATH` variable pointing to tools in bin/ Python distribution embedded in the app
2. Python applet sets `PYTHONPYCACHEPREFIX` to `/tmp/Pyc` so no .pyc compiled Python object files are written to application bundle but are redirected to /tmp dir
3. `OMC_APP_BUNDLE_PATH`, `OMC_OMC_RESOURCES_PATH`, `OMC_OMC_SUPPORT_PATH` point to locations where the scripts may find additional OMC tools, resources and scripts
4. `OMC_NIB_DLG_GUID` is an important variable with unique dialog/window instance identifier used to communicate with the window controls via `omc_dialog_control` tool
5. `OMC_CURRENT_COMMAND_GUID` is another unique uuid, representing the running command instance and could be used for various purposes like saving unique files but most often used when invoking `omc_next_command` helper tool
6. Last but not least, we have `OMC_OBJ_PATH` containing the selected file or directory path - the current context this command is invoked with.


### Step 5: Adding a table view

Double-clicking `WatchdogMonitor.nib` opens it for editing in Xcode.
The window is empty with no controls in it except the content view. Xcode experience of editing nibs is not great by default. You need to show the inspectors under View -> Inspectors -> Attributes.<br>
Now, the nib editing window should have the left pane with view hierarchy (aka document outline), central pane with window rendering and right pane with inspectors.
You add new elements to currently focused view by clicking the [+] button at the bottom of central pane (aka "Show Library"). A window pops up with choices of elements. Find "Table View". Table view is inserted inside a wrapping Scroll View. In sizing inspector you will want to set the scroll view auto-sizing rules.<br>
Digging through the view hierarchy in the left pane when you select the actual embedded Table View you need to make changes in the inspectors. In "Identity" inspector you should change "Class" from NSTableView to OMCTableView. This adds support for OMC engine features in the table. Switching to "Attributes" inspector, you need to change the "Content Mode" from "View Based" to "Cell Based" because this is what OMC engine supports. Last, but not least you need to change the view "Tag" from 0 to 1. This is the important part. This control now has the identifier = 1 and can be found and manipulated by OMC by its identifier. <br>
There are other settings you may want to apply and make some tweaks for the appearance of the table and its cells. At this point we don't change the number of columns or name them - this will be done in the code soon.

With this addition we can start the applet again and see that the table is displayed but it is empty and is not set up. The setup is going to happen in "watchdog.monitor.init.py" script which we already created and it is invoked on window initialization.
In order to set up the controls in the window we will use "omc_dialog_control" tool, which is located inside "Support" folder. We obtain the location from env variable exported for us by OMC engine:
`omc_support_path = os.environ.get("OMC_OMC_SUPPORT_PATH")`<br>
And construct:
`dialog_tool = os.path.join(omc_support_path, "omc_dialog_control")`<br>
We will also need:
`dlg_guid = os.environ.get("OMC_NIB_DLG_GUID")`<br>

This allows us set up the dialog controls by sending the information to the window via `omc_dialog_control` tool. This is cross-process communication because the handler script is running in a separate process from the applet code with the window.
See more information at: [omc_dialog_control--help](https://github.com/abra-code/OMC/blob/master/omc_dialog_control--help.md).<br>
Finally the multiple elements come together:
- dlg_guid uniquely identifies the window instance we are sending the message to
- "1" is the control we are targeting (as we set the Table View "tag" in Xcode)
- "omc_table_set_columns" and "omc_table_set_column_widths" are special instructions to set up the table column titles and widths

```
subprocess.run([dialog_tool, dlg_guid, "1", "omc_table_set_columns", "Time", "📁", "🚩", "Path"])
subprocess.run([dialog_tool, dlg_guid, "1", "omc_table_set_column_widths", "120", "20", "20", "580"])

```

If we run our applet at this point, the table should look much better with all columns set up but still empty.
The last piece of the puzzle is to populate the rows. OMC expects tab-separated text to be sent to the table view, which gets parsed, split and assigned to proper columns.
We add row population to event.sh, instead of echoing the text to a stdout:
```
event_row="${timestamp}\t${watch_object}\t${watch_event_type}\t${watch_src_path}\t${watch_dest_path}"
echo "${event_row}" | "$dialog_tool" "$OMC_NIB_DLG_GUID" 1 omc_table_add_rows_from_stdin
```
Running Watchodg.app should now add rows to the table view on each registered file system event. As a test, monitoring your `~Library` should provide a lot of frequent file events to populate your table, especially quite active "Preferences" folder, where plists get deleted and re-created (plist files are rarely "edited" but rather mutated in-memory and written back to a new file).


### Step 6: Adding Start/Stop Controls and Filtering

The basic implementation starts monitoring and outputting events in the table view. Now let's add explicit start/stop buttons, provide GUI options for watchmedo arguments other functionality.


**New Dialog Controls** (WatchdogMonitor.nib)
| Control | Tag | Purpose |
|---------|-----|---------|
| Checkbox | 2 | "Observe files in subdirectories" - toggles recursive monitoring |
| Checkbox | 3 | "Include directory events" - shows directory create/delete/modify events |
| TextField | 4 | "Watch files matching:" - glob pattern filter (e.g., `*.txt;*.rtf`) |
| TextField | 5 | "Ignore files matching:" - exclusion pattern (e.g., `*.tmp;*.temp`) |
| Button | 6 | ▶️ Start monitoring |
| Button | 7 | ⏹️ Stop monitoring |
| Button | 8 | 🔍 Reveal in Finder |
| Button | 9 | ℹ️ File info |
| Button | 10 | 📋 Copy selected rows |
| Button | - | 🗑️ Clear events list |
| Button | - | ⬇️ Export events to TSV |

**Table Selection Handling:**
Added `selectionCommandID="watchdog.monitor.selection.change"` to OMCTableView "User Defined Runtime Attributes". This triggers a command when row selection changes, enabling or disabling the selection-dependent buttons (Reveal, Info, Copy).

**New Commands in Command.plist:**

```
watchdog.monitor.start    - Begin monitoring with current settings
watchdog.monitor.stop     - Stop running monitor
watchdog.monitor.restart  - Restart monitor (triggered by checkbox changes)
watchdog.reveal.in.finder - Reveal selected file in Finder
watchdog.file.info        - Display select file(s) information in output window
watchdog.copy.event       - Copy selected row(s) to clipboard
watchdog.monitor.selection.change - Handle table selection changes
watchdog.export.events    - Export event log to TSV file
watchdog.clear.event.list - Clear all events from table
```

**Export Dialog Configuration:**
The export command uses `SAVE_AS_DIALOG` to present a save panel:
```
<key>SAVE_AS_DIALOG</key>
<dict>
    <key>MESSAGE</key>
    <string>Save Event Log As...</string>
    <key>DEFAULT_FILE_NAME</key>
    <array>
        <string>watchdog_events_</string>
        <string>__OBJ_NAME__</string>
        <string>.tsv</string>
    </array>
    <key>DEFAULT_LOCATION</key>
    <array>
        <string>~</string>
    </array>
</dict>
```
The `OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS` environment variable provides tab-separated data for all rows.

**Script Organization Changes:**

The main startup script `Watchdog.main.sh` is simplified just to verify we got a directory from context (file dropped on the app or opened from navigation dialog).

**Auto-Start on Window Open:**
Updated `watchdog.monitor.init.py` to automatically start monitoring when the window opens:
```python
next_command_tool = os.path.join(omc_support_path, "omc_next_command")
current_command_guid = os.environ.get("OMC_CURRENT_COMMAND_GUID")
subprocess.run([next_command_tool, current_command_guid, "watchdog.monitor.start"])
```

**Termination Handler Improvement:**
Updated `app.will.terminate.sh` to use more targeted process killing:
```
PYTHON_BIN="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/"
/usr/bin/pkill -U "${USER}" -f "${PYTHON_BIN}.*"
```

Using `-U ${USER}` ensures we only kill our own Python processes, avoiding potential issues with other users' processes.

**Shell vs Python Implementation:**

All scripts can be written in either shell or Python. The original implementations used shell scripts (`.sh`), but then they were translated to Python (`.py`). OMC executes scripts by matching the COMMAND_ID to a file without extension, so the working implementation can be either `.sh` or `.py`. The `.sh` versions are preserved in `Scripts-shell/` directory for reference.


**Reading UI Control Values:**

OMC exports control values as environment variables when subcommands are triggered from dialog controls. The format is:
- `$OMC_NIB_DIALOG_CONTROL_N_VALUE` for single-value controls (text fields, checkboxes)
- `$OMC_NIB_TABLE_NNN_COLUMN_MMM_VALUE` for table cell values

**Reading Control Values in Shell:**
```bash
# TextField with tag 4: watch pattern
WATCH_PATTERN="${OMC_NIB_DIALOG_CONTROL_4_VALUE}"

# TextField with tag 5: ignore pattern
IGNORE_PATTERN="${OMC_NIB_DIALOG_CONTROL_5_VALUE}"

# Checkbox with tag 2: recursive mode (1=on, 0=off)
RECURSIVE="${OMC_NIB_DIALOG_CONTROL_2_VALUE}"

# Checkbox with tag 3: include directories (1=on, 0=off)
INCLUDE_DIRECTORIES="${OMC_NIB_DIALOG_CONTROL_3_VALUE}"
```

**Reading Control Values in Python:**
```python
watch_pattern = os.environ.get("OMC_NIB_DIALOG_CONTROL_4_VALUE", "")
ignore_pattern = os.environ.get("OMC_NIB_DIALOG_CONTROL_5_VALUE", "")
recursive = os.environ.get("OMC_NIB_DIALOG_CONTROL_2_VALUE", "0") == "1"
include_directories = os.environ.get("OMC_NIB_DIALOG_CONTROL_3_VALUE", "0") == "1"
```

**Selection-Dependent Actions:**

The `watchdog.monitor.selection.change` command runs whenever the table selection changes. OMC exports selected rows via environment variables in the format `$OMC_NIB_TABLE_1_COLUMN_N_VALUE` for column values.

**Column Indexing:**
- OMC table columns are 1-based (column 1, 2, 3, 4)
- Column 0 is special: it represents all columns combined into a single tab-separated string
- Any column can be used for detecting selection

---

**Code Fragments:**
For reference, here are some distilled code fragments used in action handlers illustrating the interaction with elements in GUI dialog.


**watchdog.monitor.selection.change**
Python:
```python
reveal_button_id = "8"
info_button_id = "9"
copy_button_id = "10"

dialog_tool = os.path.join(os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "omc_dialog_control")
dlg_guid = os.environ.get("OMC_NIB_DLG_GUID", "")

has_selection = os.environ.get("OMC_NIB_TABLE_1_COLUMN_1_VALUE", "") != ""
enable_disable = "omc_enable" if has_selection else "omc_disable"

subprocess.run([dialog_tool, dlg_guid, reveal_button_id, enable_disable])
subprocess.run([dialog_tool, dlg_guid, info_button_id, enable_disable])
subprocess.run([dialog_tool, dlg_guid, copy_button_id, enable_disable])
```

Shell:
```bash
reveal_button_id="8"
info_button_id="9"
copy_button_id="10"

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"

enable_disable="omc_disable"
if [ -n "${OMC_NIB_TABLE_1_COLUMN_1_VALUE}" ]; then
    enable_disable="omc_enable"
fi

"${dialog_tool}" "${OMC_NIB_DLG_GUID}" "${reveal_button_id}" "${enable_disable}"
"${dialog_tool}" "${OMC_NIB_DLG_GUID}" "${info_button_id}" "${enable_disable}"
"${dialog_tool}" "${OMC_NIB_DLG_GUID}" "${copy_button_id}" "${enable_disable}"
```

---

**watchdog.monitor.start**

Python:
```python
obj_path = os.environ.get("OMC_OBJ_PATH", "")
python = os.path.join(os.environ.get("OMC_APP_BUNDLE_PATH", ""), "Contents/Library/Python/bin/python3")
watchmedo = os.path.join(os.environ.get("OMC_APP_BUNDLE_PATH", ""), "Contents/Library/Python/bin/watchmedo")
event_sh = os.path.join(os.environ.get("OMC_APP_BUNDLE_PATH", ""), "Contents/Resources/Scripts/event.sh")

is_recursive = os.environ.get("OMC_NIB_DIALOG_CONTROL_2_VALUE", "") == "1"
is_include_dirs = os.environ.get("OMC_NIB_DIALOG_CONTROL_3_VALUE", "") == "1"
watch_recursive = "--recursive" if is_recursive else ""
watch_ignore_dirs = "" if is_include_dirs else "--ignore-directories"

pattern_list = os.environ.get("OMC_NIB_DIALOG_CONTROL_4_VALUE", "")
watch_patterns = f"--patterns={pattern_list}" if pattern_list else ""
ignore_pattern_list = os.environ.get("OMC_NIB_DIALOG_CONTROL_5_VALUE", "")
watch_ignore_patterns = f"--ignore-patterns={ignore_pattern_list}" if ignore_pattern_list else ""

dialog_tool = os.path.join(os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "omc_dialog_control")
dlg_guid = os.environ.get("OMC_NIB_DLG_GUID", "")

subprocess.run([dialog_tool, dlg_guid, "1", "omc_table_remove_all_rows"])

command_str = f"source \"{event_sh}\" \"$watch_object\" \"$watch_event_type\" \"$watch_src_path\" \"$watch_dest_path\""
args = [python, watchmedo, "shell-command", watch_recursive, watch_ignore_dirs,
        watch_patterns, watch_ignore_patterns, "--wait", "--command", command_str, obj_path]
args = [arg for arg in args if arg]

process = subprocess.Popen(args)
print(f"watchmedo started with PID: {process.pid}")

subprocess.run([dialog_tool, dlg_guid, "6", "omc_disable"])
subprocess.run([dialog_tool, dlg_guid, "7", "omc_enable"])
```

Shell:
```bash
DIR_TO_WATCH="${OMC_OBJ_PATH}"
EVENT_SH="${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/event.sh"

IS_RECURSIVE="${OMC_NIB_DIALOG_CONTROL_2_VALUE}"
WATCH_RECURSIVE=$([ "${IS_RECURSIVE}" = "1" ] && echo "--recursive" || echo "")

IS_INCLUDE_DIRS="${OMC_NIB_DIALOG_CONTROL_3_VALUE}"
WATCH_IGNORE_DIRS=$([ "${IS_INCLUDE_DIRS}" != "1" ] && echo "--ignore-directories" || echo "")

PATTERN_LIST="${OMC_NIB_DIALOG_CONTROL_4_VALUE}"
WATCH_PATTERNS=$([ -n "${PATTERN_LIST}" ] && echo "--patterns=${PATTERN_LIST}" || echo "")

IGNORE_PATTERN_LIST="${OMC_NIB_DIALOG_CONTROL_5_VALUE}"
WATCH_IGNORE_PATTERNS=$([ -n "${IGNORE_PATTERN_LIST}" ] && echo "--ignore-patterns=${IGNORE_PATTERN_LIST}" || echo "")

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
"$dialog_tool" "$OMC_NIB_DLG_GUID" 1 omc_table_remove_all_rows

"$PYTHON" "$WATCHMEDO" shell-command \
    ${WATCH_RECURSIVE} ${WATCH_IGNORE_DIRS} ${WATCH_PATTERNS} ${WATCH_IGNORE_PATTERNS} \
    --wait \
    --command='source "${EVENT_SH}" "${watch_object}" "${watch_event_type}" "${watch_src_path}" "${watch_dest_path}"' \
    "${DIR_TO_WATCH}" &
```
---

**watchdog.monitor.stop**

Shell:
```bash
WATCHMEDO="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/watchmedo"
/usr/bin/pkill -U "${USER}" -f ".* ${WATCHMEDO} shell-command .* ${OMC_OBJ_PATH}$"

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
"$dialog_tool" "$OMC_NIB_DLG_GUID" "6" omc_enable
"$dialog_tool" "$OMC_NIB_DLG_GUID" "7" omc_disable
```

---

**watchdog.monitor.restart**

Shell:
```bash
WATCHMEDO="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/watchmedo"
RUNNING_PID=$(/usr/bin/pgrep -U "${USER}" -f ".* ${WATCHMEDO} shell-command .* ${OMC_OBJ_PATH}$")

if [ -n "${RUNNING_PID}" ]; then
    source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/watchdog.monitor.stop.sh"
    source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/watchdog.monitor.start.sh"
fi
```
---

**watchdog.reveal.in.finder**

Python:
```python
file_event_paths = os.environ.get("OMC_NIB_TABLE_1_COLUMN_4_VALUE", "")
file_revealed = False

for one_path in file_event_paths.strip().split('\n'):
    one_path = one_path.strip()
    if not one_path:
        continue
    if os.path.exists(one_path):
        subprocess.run(["/usr/bin/open", "-R", one_path])
        file_revealed = True
        break

if not file_revealed:
    alert_tool = os.path.join(os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "alert")
    subprocess.run([alert_tool, "--level", "caution", "--title", "Watchdog", "File does not exist"])
```

Shell:
```bash
FILE_EVENT_PATHS="${OMC_NIB_TABLE_1_COLUMN_4_VALUE}"

FILE_REVEALED=0
while IFS= read -r one_path; do
    if [ -e "${one_path}" ]; then
        /usr/bin/open -R "${one_path}"
        FILE_REVEALED=1
        break
    fi
done <<< "$FILE_EVENT_PATHS"

if [ "${FILE_REVEALED}" = 0 ]; then
    alert="$OMC_OMC_SUPPORT_PATH/alert"
    "${alert}" --level caution --title "Watchdog" "File does not exist"
fi
```
---

**watchdog.file.info**

Python:
```python
file_event_paths = os.environ.get("OMC_NIB_TABLE_1_COLUMN_4_VALUE", "")

for one_path in file_event_paths.strip().split('\n'):
    one_path = one_path.strip()
    if not one_path:
        continue

    if os.path.exists(one_path):
        result = subprocess.run(["/usr/bin/stat", "-x", one_path], capture_output=True, text=True)
        print(result.stdout, end="")
    else:
        print(f'  File: "{one_path}"')
        print("  Status: file does not exist")
    print("---------------------------------")
```

Shell:
```bash
FILE_EVENT_PATHS="${OMC_NIB_TABLE_1_COLUMN_4_VALUE}"

while IFS= read -r one_path; do
    if [ -e "${one_path}" ]; then
        /usr/bin/stat -x "${one_path}"
    else
        echo "  File: \"${one_path}\""
        echo "  Status: file does not exist"
    fi
    echo "---------------------------------"
done <<< "$FILE_EVENT_PATHS"
```
---

**watchdog.copy.event**

Python:
```python
env = os.environ.copy()
env["LANG"] = "en_US.UTF-8"
selected_rows_text = os.environ.get("OMC_NIB_TABLE_1_COLUMN_0_VALUE", "")
subprocess.run(["/usr/bin/pbcopy", "-pboard", "general"], input=selected_rows_text, encoding="utf-8", env=env)
```

Shell:
```bash
export LANG="en_US.UTF-8"
echo "${OMC_NIB_TABLE_1_COLUMN_0_VALUE}" | /usr/bin/pbcopy -pboard general
```
---

**watchdog.clear.event.list**

Python:
```python
dialog_tool = os.path.join(os.environ.get("OMC_OMC_SUPPORT_PATH", ""), "omc_dialog_control")
subprocess.run([dialog_tool, os.environ.get("OMC_NIB_DLG_GUID", ""), "1", "omc_table_remove_all_rows"])
```

Shell:
```bash
dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
"$dialog_tool" "$OMC_NIB_DLG_GUID" 1 omc_table_remove_all_rows
```
---

**watchdog.export.events**

Python:
```python
all_rows_text = os.environ.get("OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS", "")
with open(os.environ.get("OMC_DLG_SAVE_AS_PATH", ""), "w", encoding="utf-8") as f:
    f.write(all_rows_text)
```


Shell:
```bash
echo "${OMC_NIB_TABLE_1_COLUMN_0_ALL_ROWS}" > "${OMC_DLG_SAVE_AS_PATH}"
```
---

**app.will.terminate**

Python:
```python
python_bin = os.path.join(os.environ.get("OMC_APP_BUNDLE_PATH", ""), "Contents", "Library", "Python", "bin", "")
subprocess.run(["/usr/bin/pkill", "-U", os.environ.get("USER", ""), "-f", f"{python_bin}.*"])
```

Shell:
```bash
PYTHON_BIN="${OMC_APP_BUNDLE_PATH}/Contents/Library/Python/bin/"
/usr/bin/pkill -U "${USER}" -f "${PYTHON_BIN}.*"
```



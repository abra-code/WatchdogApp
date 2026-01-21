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
arch -x86_64 ./python3 -m pip install watchdog --no-binary=watchdog

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
`ENVIRONMENT_VARIABLES={OMC_OBJ_PATH=''}` - we tell the OMC engine the script always needs object path (object being directory in our case)<br>
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

Printing environment variables will help us understand which variables are set up by OMC engine upon stript execution in any given context. Again, in order to see the output you need to hold "control" key when the command is starting. Or temporarily set `EXECUTION_MODE=exe_script_file_with_output_window` for initial debugging.

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

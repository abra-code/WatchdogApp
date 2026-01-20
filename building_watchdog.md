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

In order to start `watchmedo` inside Watchdog.app we need to create a command description with script handler and declare it in Command.plist
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

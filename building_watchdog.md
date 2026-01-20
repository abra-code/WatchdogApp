# Building Watchdog.app

## Step-by-step guide how Watchdog.app is created.

### Step 1: Basic Python applet
Clone [OMC](https://github.com/abra-code/OMC/) at `~/git/OMC/`
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

We create a new applet by using `~/git/OMC/build_applet.sh` and pointing to OMCPythonApplet.app template.
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
`Architectures in the fat file: ../lib/python3.14/site-packages/_watchdog_fsevents.cpython-314-darwin.so are: x86_64 arm64 `
Now we are ready to try `watchmedo` tool:
```
./python3 watchmedo --help
./python3 watchmedo log --help
./python3 watchmedo log --verbose --recursive ~/Downloads
```
At that point the `watchmedo` tool enters a runloop observing `~/Downloads` and waiting for something to happen there. Add or remove a file. modify some text and see the file events begin reported by `watchmedo` in Terminal.

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

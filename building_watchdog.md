# Building Watchdog.app

## Step-by-step guide how Watchdog.app is created.

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
These exclude files are NOT present in the repo but are created locally when following the build steps.

Watchdog.icon was created using [Icon Composer.app](https://developer.apple.com/icon-composer/) and placed in `~/git/WatchdogApp/Icon/`

We create a new applet by using "~/git/OMC/build_applet.sh" and pointing to OMCPythonApplet.app template.
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


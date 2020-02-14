# aosp-10

Scripts that build aosp 10 for xperia devices using linux kernel 4.9 or 4.14 and including opengapps.

A usage description of the scripts can be displayed via:
```
build-4.x.sh -h|--help
```

Please be aware that these scripts are not appropriate for a developer aosp tree that contains
changes but should only be used on clean trees, since the script will do things like:
- delete files
- git hard resets
- git checkouts

For general build instructions how to setup and build aosp for xperia see:\
https://developer.sony.com/develop/open-devices/guides/aosp-build-instructions

The script contains following variables that can be set from outside.
The value after the colon is the default value.
```
SOURCE=${SOURCE:-~/android/source}
LUNCH_CHOICE=${LUNCH_CHOICE:-aosp_g8441-userdebug}
PLATFORM=${PLATFORM:-yoshino}
DEVICE=${DEVICE:-lilac}
```

To build nile, using kernel 4.9 following script call has to be done:
```
env LUNCH_CHOICE=aosp_h3113-userdebug PLATFORM=nile DEVICE=pioneer ./build-4.9.sh
```

[WIP] NOT YET TESTED!!!\
To switch to a different branch before building, call the script as follows:
```
./build-4.x.sh -b android-10.0.0_rXX
```
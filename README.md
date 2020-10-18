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
LUNCH_CHOICE=
```

To build nile, using kernel 4.9 following script call has to be done:
```
env LUNCH_CHOICE=aosp_h3113-userdebug ./build-4.9.sh
```

To switch to a different branch before building, call the script as follows:
```
./build-4.x.sh -b android-10.0.0_rXX
```

To switch to the 2020-02-05 branch while keeping the `.repo/local_manifests/` on the current
branch (e.g. android-10.0.0_r21) and building aosp 10 with kernel 4.9 use:
```
./build-4.9.sh -b android-10.0.0_r26 -k
```

Please be aware that switching the aosp branch and keeping the local manifests branch is **not**
officially supported by the sodp (Sony Open Device Project).

An overview of available branches can be found here:\
https://source.android.com/setup/start/build-numbers

#### Flashing aosp 10 build when kernel 4.9 is used
For the OEM partition the latest:
"Sofware binaries for AOSP Pie (Android 9.0) – Kernel 4.9" have to be used.\
Download from: https://developer.sony.com/develop/open-devices/latest-updates \
Version: SW_binaries_for_Xperia_Android_9.0_2.3.2_v9

Trying to use the software binaries for "Kernel Android 10.0 (Kernel 4.14)" won't work.

#### Known issues for aosp 10 and software binaries for kernel 4.9
- aptX: aptX is not working. Reason for that is that the aptX blobs in the software binaries from kernel
4.9 are not compatible with aosp 10.\
Workaround: Deactivate aptX, after coupling a device via BT. Click the gear in the BT
settings for the coupled device within Android and switch off HD-Audio: Qualcomm aptX-Audio.\
See as well: https://github.com/sonyxperiadev/device-sony-common/pull/718

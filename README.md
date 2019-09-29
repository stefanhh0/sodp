# aosp-10

Script that builds aosp 10 for xperia devices together with linux kernel 4.9 and opengapps.

Please be aware that this script is not appropriate for a developer aosp tree with uncommitted 
changes but should only be used on clean trees, since the script will do things like:
- delete files
- git hard resets
- git checkouts

For general build instructions how to setup and build aosp xperia see:
https://developer.sony.com/develop/open-devices/guides/aosp-build-instructions

The script needs to be adjusted for your build via setting these variables accordingly:
```
SOURCE=~/android/source
APK=~/android/q
LUNCH_CHOICE=aosp_g8441-userdebug
PLATFORM=yoshino
DEVICE=lilac
```

For opengapps it is required to obtain three APKs manually and provide them in the APK folder.
The apks can be obtained from a pixel 10 image e.g. from crosshatch: 
https://developers.google.com/android/images

Following APKs are required:
- `$APK/GooglePackageInstaller.apk`
- `$APK/GooglePermissionControllerPrebuilt.apk`
- `$APK/SetupWizardPrebuilt.apk`

#!/bin/bash
set -e

# ----------------------------------------------------------------------
# Variables have to be adjusted accordingly
# ----------------------------------------------------------------------
SOURCE=~/android/source
APK=~/android/q
LUNCH_CHOICE=aosp_g8441-userdebug
PLATFORM=yoshino
DEVICE=lilac
# ----------------------------------------------------------------------

pick_pr() {
    local REMOTE=$1
    local PR_ID=$2
    local COMMITS=$3
    local INDEX=$(($COMMITS - 1))

    git fetch $REMOTE pull/$PR_ID/head

    while [ $INDEX -ge 0 ]; do
        git cherry-pick -Xtheirs --no-edit FETCH_HEAD~$INDEX
        INDEX=$(($INDEX - 1))
    done
}

cd $SOURCE

ANDROID_VERSION=`cat .repo/manifest.xml|grep default\ revision|sed 's#^.*refs/tags/\(.*\)"#\1#1'`

if [ -d kernel/sony/msm-4.14 ]; then
   rm -r kernel/sony/msm-4.14
fi

if [ -d device/sony/customization/ ]; then
    rm -r device/sony/customization
fi

for path in \
device/sony/common \
device/sony/sepolicy \
device/sony/$PLATFORM \
kernel/sony/msm-4.9/kernel \
kernel/sony/msm-4.9/common-kernel \
vendor/opengapps/sources/all \
vendor/opengapps/sources/arm \
vendor/opengapps/sources/arm64 \
vendor/oss/fingerprint \
vendor/oss/transpower \
vendor/qcom/opensource/location
do
    if [ -d $path ]; then
        pushd $path
            git clean -d -f
            git reset --hard m/$ANDROID_VERSION
        popd
    fi
done

# ----------------------------------------------------------------------
# Manifest adjustments
# ----------------------------------------------------------------------
pushd .repo/manifests
    git clean -d -f
    git checkout .
    git pull

    # ----------------------------------------------------------------------
    # Include opengapps repos
    # ----------------------------------------------------------------------
    patch -p1 <<EOF
diff --git a/default.xml b/default.xml
index 18983252..134ba366 100644
--- a/default.xml
+++ b/default.xml
@@ -768,4 +768,16 @@

   <repo-hooks in-project="platform/tools/repohooks" enabled-list="pre-upload" />

+  <remote name="opengapps" fetch="https://github.com/MarijnS95/"  />
+  <!--<remote name="opengapps" fetch="https://github.com/opengapps/"  />-->
+  <remote name="gitlab" fetch="https://gitlab.opengapps.org/opengapps/"  />
+
+  <project path="vendor/opengapps/build" name="opengapps_aosp_build" revision="master" remote="opengapps" />
+  <!--<project path="vendor/opengapps/build" name="aosp_build" revision="master" remote="opengapps" />-->
+
+  <project path="vendor/opengapps/sources/all" name="all" clone-depth="1" revision="master" remote="gitlab" />
+
+  <!-- arm64 depends on arm -->
+  <project path="vendor/opengapps/sources/arm" name="arm" clone-depth="1" revision="master" remote="gitlab" />
+  <project path="vendor/opengapps/sources/arm64" name="arm64" clone-depth="1" revision="master" remote="gitlab" />
 </manifest>
EOF
popd

# ----------------------------------------------------------------------
# Local manifest adjustments
# ----------------------------------------------------------------------
pushd .repo/local_manifests
    git clean -d -f
    git fetch
    git reset --hard origin/$ANDROID_VERSION
    rm LA.UM.7.1.r1.xml

    # remove the no-op Android.bp
    git revert --no-edit f2bc4d5e1bfd7d4b48d373350b70dac49c70d2af

    # add display-commonsys-intf git
    git revert --no-edit 52af0a25c9d863179068d912ff1e231639f8de43

    # revert switch display to aosp/LA.UM.7.1.r1
    patch -p1 <<EOF
diff --git a/qcom.xml b/qcom.xml
index 27bc6b7..99d0487 100644
--- a/qcom.xml
+++ b/qcom.xml
@@ -9,9 +9,8 @@

 <project path="hardware/qcom/gps" name="platform/hardware/qcom/sdm845/gps" remote="aosp" groups="qcom_sdm845" />

-<project path="hardware/qcom/display/sde" name="hardware-qcom-display" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" />
-<project path="hardware/qcom/media/sm8150" name="hardware-qcom-media" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" />

+<project path="hardware/qcom/display/sde" name="hardware-qcom-display" groups="device" remote="sony" revision="aosp/LA.UM.7.3.r1" />
 <project path="hardware/qcom/media/sdm845" name="platform/hardware/qcom/sdm845/media" groups="qcom_sdm845" remote="aosp" />

 <project path="hardware/qcom/data/ipacfg-mgr/sdm845" name="platform/hardware/qcom/sdm845/data/ipacfg-mgr" groups="qcom_sdm845" remote="aosp" />
@@ -21,7 +19,7 @@
 <project path="vendor/qcom/opensource/dataservices" name="vendor-qcom-opensource-dataservices" groups="device" remote="sony" revision="master" />
 <project path="vendor/qcom/opensource/location" name="vendor-qcom-opensource-location" groups="device" remote="sony" revision="p-mr0" />
 <project path="vendor/qcom/opensource/wlan" name="hardware-qcom-wlan" groups="device" remote="sony" revision="master" />
-<project path="vendor/qcom/opensource/interfaces" name="vendor-qcom-opensource-interfaces" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" >
+<project path="vendor/qcom/opensource/interfaces" name="vendor-qcom-opensource-interfaces" groups="device" remote="sony" revision="aosp/LA.UM.7.3.r1" >
   <linkfile dest="vendor/qcom/opensource/Android.bp" src="os_pickup.bp" />
 </project>
 </manifest>
EOF

    # ----------------------------------------------------------------------
    # 4.9 kernel-repos
    # ----------------------------------------------------------------------
    cat >LE.UM.2.3.2.r1.4.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
<remote name="sony" fetch="https://github.com/sonyxperiadev/" />
<remote name="marijns95" fetch="https://github.com/MarijnS95/" />
<project path="kernel/sony/msm-4.9/common-headers" name="device-sony-common-headers" groups="device" remote="sony" revision="aosp/LE.UM.2.3.2.r1.4" />
<project path="kernel/sony/msm-4.9/common-kernel" name="kernel-sony-msm-4.9-common" groups="device" remote="marijns95" revision="aosp/LE.UM.2.3.2.r1.4" clone-depth="1" />
<project path="kernel/sony/msm-4.9/kernel" name="kernel" groups="device" remote="sony" revision="aosp/LE.UM.2.3.2.r1.4" />
<project path="kernel/sony/msm-4.9/kernel/arch/arm64/configs/sony" name="kernel-defconfig" groups="device" remote="sony" revision="aosp/LE.UM.2.3.2.r1.4" />
<project path="kernel/sony/msm-4.9/kernel/drivers/staging/wlan-qc/fw-api" name="vendor-qcom-opensource-wlan-fw-api" groups="device" remote="sony" revision="aosp/LA.UM.7.3.r1" />
<project path="kernel/sony/msm-4.9/kernel/drivers/staging/wlan-qc/qca-wifi-host-cmn" name="vendor-qcom-opensource-wlan-qca-wifi-host-cmn" groups="device" remote="sony" revision="aosp/LA.UM.7.3.r1" />
<project path="kernel/sony/msm-4.9/kernel/drivers/staging/wlan-qc/qcacld-3.0" name="vendor-qcom-opensource-wlan-qcacld-3.0" groups="device" remote="sony" revision="aosp/LA.UM.7.3.r1" />
</manifest>
EOF
popd

./repo_update.sh

if [ -d kernel/sony/msm-4.14 ]; then
   rm -r kernel/sony/msm-4.14
fi

pushd device/sony/common
    sed -i 's/TARGET_VENDOR_VERSION := .*/TARGET_VENDOR_VERSION := v9/1' common-odm.mk
    sed -i 's/QCOM_NEW_MEDIA_PLATFORM := .*/QCOM_NEW_MEDIA_PLATFORM := sdm845 sm8150/1' hardware/qcom/Android.mk

    # remove the no-op Android.bp
    git revert --no-edit fd3e6c8c993d3aa7ef7ae9856d37dc09d4bbcf3f

    # PowerHAL: power-helper: Fix WLAN STATS file path for k4.14
    git revert --no-edit d3cbedf701aa8ab1ed7d571b5fb384665c92df03

    # liblights: Migrate to kernel 4.14 LED class for RGB tri-led
    git revert --no-edit 8b79a2321abe42c9d13540651cbf8a276ec7a2f1

    git fetch https://github.com/MarijnS95/device-sony-common
    # common-packages: Include default thermal hw module.
    git cherry-pick --no-edit 2ebad1b02a8f007510f5398b1f9041a17495978e
popd

pushd device/sony/sepolicy
    git fetch https://github.com/MarijnS95/device-sony-sepolicy
    # WIP: Copy hal_thermal_default from crosshatch.
    git cherry-pick --no-edit 6327e77551a688701719aa5438f63e0121c296fd
popd

pushd device/sony/$PLATFORM
    sed -i 's/SOMC_KERNEL_VERSION := .*/SOMC_KERNEL_VERSION := 4.9/1' platform.mk

    # ueventd: Fix Tri-LED path permissions
    git revert --no-edit `git log --pretty=format:"%H %s"|grep "ueventd: Fix Tri-LED path permissions" |awk '{print $1}'`
popd

pushd vendor/qcom/opensource/location
    # switch to kernel 4.14
    git revert --no-edit a74c2656de1265eefd2fdc48030c615e400c5a3e
popd

# ----------------------------------------------------------------------
# Pull opengapps large files that are stored in git lfs
# ----------------------------------------------------------------------
for path in \
vendor/opengapps/sources/all \
vendor/opengapps/sources/arm \
vendor/opengapps/sources/arm64
do
    pushd $path
        git lfs pull &
    popd
done
wait

# ----------------------------------------------------------------------
# opengapps permissions-google
# ----------------------------------------------------------------------
pushd vendor/opengapps/sources/all
    patch -p1 <<EOF
diff --git a/etc/permissions/privapp-permissions-google.xml b/etc/permissions/privapp-permissions-google.xml
index 0b46f07..2d2e5cd 100644
--- a/etc/permissions/privapp-permissions-google.xml
+++ b/etc/permissions/privapp-permissions-google.xml
@@ -81,12 +81,14 @@ It allows additional grants on top of privapp-permissions-platform.xml
         <permission name="android.permission.MANAGE_USERS"/>
         <permission name="android.permission.PACKAGE_USAGE_STATS"/>
         <permission name="android.permission.PACKAGE_VERIFICATION_AGENT"/>
+        <permission name="android.permission.READ_PRIVILEGED_PHONE_STATE"/>
         <permission name="android.permission.READ_RUNTIME_PROFILES"/>
         <permission name="android.permission.REAL_GET_TASKS"/>
-        <permission name="android.permission.READ_PRIVILEGED_PHONE_STATE" />
-        <permission name="android.permission.REBOOT" />
+        <permission name="android.permission.REBOOT"/>
+        <permission name="android.permission.SEND_DEVICE_CUSTOMIZATION_READY"/>
         <permission name="android.permission.SEND_SMS_NO_CONFIRMATION"/>
         <permission name="android.permission.SET_PREFERRED_APPLICATIONS"/>
+        <permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND"/>
         <permission name="android.permission.STATUS_BAR"/>
         <permission name="android.permission.SUBSTITUTE_NOTIFICATION_APP_NAME"/>
         <permission name="android.permission.UPDATE_DEVICE_STATS"/>
@@ -297,6 +299,7 @@ It allows additional grants on top of privapp-permissions-platform.xml
         <permission name="android.permission.CONNECTIVITY_USE_RESTRICTED_NETWORKS"/>
         <permission name="android.permission.CONTROL_INCALL_EXPERIENCE"/>
         <permission name="android.permission.CONTROL_DISPLAY_SATURATION"/>
+        <permission name="android.permission.CONTROL_KEYGUARD_SECURE_NOTIFICATIONS"/>
         <permission name="android.permission.DISPATCH_PROVISIONING_MESSAGE"/>
         <permission name="android.permission.DUMP"/>
         <permission name="android.permission.GET_APP_OPS_STATS"/>
@@ -305,7 +308,7 @@ It allows additional grants on top of privapp-permissions-platform.xml
         <permission name="android.permission.INVOKE_CARRIER_SETUP"/>
         <permission name="android.permission.LOCAL_MAC_ADDRESS"/>
         <permission name="android.permission.LOCATION_HARDWARE"/>
-        <permission name="android.permission.MANAGE_ACTIVITY_STACKS"/>
+        <permission name="android.permission.LOCK_DEVICE"/>
         <permission name="android.permission.MANAGE_DEVICE_ADMINS"/>
         <permission name="android.permission.MANAGE_SOUND_TRIGGER"/>
         <permission name="android.permission.MANAGE_SUBSCRIPTION_PLANS"/>
@@ -331,12 +334,16 @@ It allows additional grants on top of privapp-permissions-platform.xml
         <permission name="android.permission.RECOVER_KEYSTORE"/>
         <permission name="android.permission.RECOVERY"/>
         <permission name="android.permission.REGISTER_CALL_PROVIDER"/>
+        <permission name="android.permission.REMOTE_DISPLAY_PROVIDER"/>
+        <permission name="android.permission.RESET_PASSWORD"/>
         <permission name="android.permission.SCORE_NETWORKS"/>
         <permission name="android.permission.SEND_SMS_NO_CONFIRMATION"/>
         <permission name="android.permission.SET_TIME"/>
         <permission name="android.permission.SET_TIME_ZONE"/>
+        <permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND"/>
         <permission name="android.permission.START_TASKS_FROM_RECENTS"/>
         <permission name="android.permission.SUBSTITUTE_NOTIFICATION_APP_NAME"/>
+        <permission name="android.permission.SUBSTITUTE_SHARE_TARGET_APP_NAME_AND_ICON"/>
         <permission name="android.permission.TETHER_PRIVILEGED"/>
         <permission name="android.permission.UPDATE_APP_OPS_STATS"/>
         <permission name="android.permission.USE_RESERVED_DISK"/>
@@ -437,14 +444,25 @@ It allows additional grants on top of privapp-permissions-platform.xml
         <permission name="android.permission.CHANGE_COMPONENT_ENABLED_STATE"/>
     </privapp-permissions>

+    <privapp-permissions package="com.google.android.permissioncontroller">
+        <permission name="android.permission.MANAGE_USERS"/>
+        <permission name="android.permission.OBSERVE_GRANT_REVOKE_PERMISSIONS"/>
+        <permission name="android.permission.GET_APP_OPS_STATS"/>
+        <permission name="android.permission.UPDATE_APP_OPS_STATS"/>
+        <permission name="android.permission.REQUEST_INCIDENT_REPORT_APPROVAL"/>
+        <permission name="android.permission.APPROVE_INCIDENT_REPORTS"/>
+        <permission name="android.permission.READ_PRIVILEGED_PHONE_STATE" />
+        <permission name="android.permission.SUBSTITUTE_NOTIFICATION_APP_NAME" />
+    </privapp-permissions>
+
     <privapp-permissions package="com.google.android.packageinstaller">
-        <permission name="android.permission.CLEAR_APP_CACHE"/>
         <permission name="android.permission.DELETE_PACKAGES"/>
         <permission name="android.permission.INSTALL_PACKAGES"/>
+        <permission name="android.permission.USE_RESERVED_DISK"/>
         <permission name="android.permission.MANAGE_USERS"/>
-        <permission name="android.permission.OBSERVE_GRANT_REVOKE_PERMISSIONS"/>
         <permission name="android.permission.UPDATE_APP_OPS_STATS"/>
-        <permission name="android.permission.USE_RESERVED_DISK"/>
+        <permission name="android.permission.SUBSTITUTE_NOTIFICATION_APP_NAME"/>
+        <permission name="android.permission.PACKAGE_USAGE_STATS"/>
     </privapp-permissions>

     <privapp-permissions package="com.google.android.partnersetup">
@@ -488,11 +506,12 @@ It allows additional grants on top of privapp-permissions-platform.xml
         <permission name="android.permission.PERFORM_CDMA_PROVISIONING"/>
         <permission name="android.permission.READ_PRIVILEGED_PHONE_STATE"/>
         <permission name="android.permission.REBOOT"/>
-        <permission name="android.permission.REQUEST_NETWORK_SCORES"/>
         <permission name="android.permission.SET_TIME"/>
         <permission name="android.permission.SET_TIME_ZONE"/>
         <permission name="android.permission.SHUTDOWN"/>
         <permission name="android.permission.STATUS_BAR"/>
+        <permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND"/>
+        <permission name="android.permission.SUBSTITUTE_NOTIFICATION_APP_NAME"/>
         <permission name="android.permission.WRITE_APN_SETTINGS"/>
         <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
     </privapp-permissions>
@@ -576,11 +596,15 @@ It allows additional grants on top of privapp-permissions-platform.xml
     </privapp-permissions>

     <privapp-permissions package="com.google.android.apps.wellbeing">
+        <permission name="android.permission.ACCESS_INSTANT_APPS"/>
+        <permission name="android.permission.CONTROL_DISPLAY_COLOR_TRANSFORMS"/>
         <permission name="android.permission.CONTROL_DISPLAY_SATURATION"/>
+        <permission name="android.permission.INTERACT_ACROSS_PROFILES"/>
         <permission name="android.permission.LOCATION_HARDWARE"/>
         <permission name="android.permission.MODIFY_PHONE_STATE"/>
         <permission name="android.permission.OBSERVE_APP_USAGE"/>
         <permission name="android.permission.PACKAGE_USAGE_STATS"/>
+        <permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND"/>
         <permission name="android.permission.SUBSTITUTE_NOTIFICATION_APP_NAME"/>
         <permission name="android.permission.SUSPEND_APPS"/>
         <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
EOF
popd

# ----------------------------------------------------------------------
# customization to build opengapps
# ----------------------------------------------------------------------
mkdir device/sony/customization
cat >device/sony/customization/customization.mk <<EOF
GAPPS_VARIANT := pico

GAPPS_PRODUCT_PACKAGES += \\
    Chrome \\
    GooglePackageInstaller \\
    GooglePermissionController \\
    SetupWizard

WITH_DEXPREOPT := true

GAPPS_FORCE_WEBVIEW_OVERRIDES := true
GAPPS_FORCE_BROWSER_OVERRIDES := true

\$(call inherit-product, vendor/opengapps/build/opengapps-packages.mk)
EOF

# ----------------------------------------------------------------------
# Copy required apks for android 10 that are not yet in opengapps.
# The apks can be obtained from:
# https://developers.google.com/android/images
#
# The apks used here are downloaded via extract-apks.sh
#
# If using a different image, version numbers might be different and
# have to be adjusted using the versionCode from the command:
# aapt dump badging <name>.apk |grep versionCode
# ----------------------------------------------------------------------
# PackageInstaller
# ----------------------------------------------------------------------
mkdir -p vendor/opengapps/sources/all/priv-app/com.google.android.packageinstaller/29/nodpi
cp $APK/GooglePackageInstaller.apk vendor/opengapps/sources/all/priv-app/com.google.android.packageinstaller/29/nodpi/29.apk

# ----------------------------------------------------------------------
# PermissionController
# ----------------------------------------------------------------------
mkdir -p vendor/opengapps/sources/arm64/app/com.google.android.permissioncontroller/29/nodpi
cp $APK/GooglePermissionControllerPrebuilt.apk vendor/opengapps/sources/arm64/app/com.google.android.permissioncontroller/29/nodpi/291900200.apk

# ----------------------------------------------------------------------
# SetupWizard
# ----------------------------------------------------------------------
mkdir -p vendor/opengapps/sources/all/priv-app/com.google.android.setupwizard.default/29/nodpi
cp $APK/SetupWizardPrebuilt.apk vendor/opengapps/sources/all/priv-app/com.google.android.setupwizard.default/29/nodpi/2842.apk

. build/envsetup.sh
lunch $LUNCH_CHOICE

make clean

pushd kernel/sony/msm-4.9/common-kernel
    PLATFORM_UPPER=`echo $PLATFORM|tr '[:lower:]' '[:upper:]'`
    sed -i "s/PLATFORMS=.*/PLATFORMS=$PLATFORM/1" build-kernels-gcc.sh
    sed -i "s/$PLATFORM_UPPER=.*/$PLATFORM_UPPER=$DEVICE/1" build-kernels-gcc.sh
    find . -name "*dtb*" -exec rm "{}" \;
    bash ./build-kernels-gcc.sh
popd

make -j`nproc --all`

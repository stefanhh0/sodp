#!/bin/bash
set -e

# ----------------------------------------------------------------------
# Variables have to be adjusted accordingly
# ----------------------------------------------------------------------
SOURCE=~/android/source
LUNCH_CHOICE=aosp_g8441-userdebug
PLATFORM=yoshino
DEVICE=lilac
# ----------------------------------------------------------------------

pick_pr() {
    local REMOTE=$1
    local PR_ID=$2
    local COMMITS=$3
    local MAX_COMMITS=$4
    local INDEX=$(($COMMITS - 1))
    local COUNT=0

    if [ -z $MAX_COMMITS ]; then
        MAX_COMMITS=$COMMITS
    fi

    git fetch $REMOTE pull/$PR_ID/head

    while [ $INDEX -ge 0 -a $COUNT -lt $MAX_COMMITS ]; do
        git cherry-pick -Xtheirs --no-edit FETCH_HEAD~$INDEX
        INDEX=$(($INDEX - 1))
        COUNT=$(($COUNT + 1))
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
vendor/opengapps/build \
vendor/opengapps/sources/all \
vendor/opengapps/sources/arm \
vendor/opengapps/sources/arm64 \
vendor/oss/fingerprint \
vendor/oss/transpower \
vendor/qcom/opensource/location
do
    if [ -d $path ]; then
        pushd $path
            git clean -d -f -e "*dtb*"
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
@@ -768,4 +768,12 @@

   <repo-hooks in-project="platform/tools/repohooks" enabled-list="pre-upload" />

+  <remote name="opengapps" fetch="https://github.com/opengapps/" />
+  <remote name="gitlab" fetch="https://gitlab.opengapps.org/opengapps/" />
+
+  <project path="vendor/opengapps/build" name="aosp_build" revision="master" remote="opengapps" />
+  <project path="vendor/opengapps/sources/all" name="all" clone-depth="1" revision="ten" remote="gitlab" />
+  <!-- arm64 depends on arm -->
+  <project path="vendor/opengapps/sources/arm" name="arm" clone-depth="1" revision="ten" remote="gitlab" />
+  <project path="vendor/opengapps/sources/arm64" name="arm64" clone-depth="1" revision="ten" remote="gitlab" />
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
    #TEMP: Kernel 4.9 backward compat
    pick_pr sony 666 1

    # remove the no-op Android.bp
    git revert --no-edit fd3e6c8c993d3aa7ef7ae9856d37dc09d4bbcf3f

    # PowerHAL: power-helper: Fix WLAN STATS file path for k4.14
    git revert --no-edit d3cbedf701aa8ab1ed7d571b5fb384665c92df03

    # liblights: Migrate to kernel 4.14 LED class for RGB tri-led
    git revert --no-edit 8b79a2321abe42c9d13540651cbf8a276ec7a2f1

    git fetch https://github.com/MarijnS95/device-sony-common
    # common-packages: Include default thermal hw module.
    git cherry-pick --no-edit ed49f27232ec118ca6f5378fc132f63ea836521a
popd

pushd device/sony/sepolicy
    git fetch https://github.com/MarijnS95/device-sony-sepolicy
    # WIP: Copy hal_thermal_default from crosshatch.
    git cherry-pick --no-edit 2974bc6a5497c945a72df3882bc032aa741ce443
popd

pushd device/sony/$PLATFORM
    sed -i 's/SOMC_KERNEL_VERSION := .*/SOMC_KERNEL_VERSION := 4.9/1' platform.mk

    # ueventd: Fix Tri-LED path permissions
    TRI_LED_COMMIT=`git log --pretty=format:"%H %s"|grep "ueventd: Fix Tri-LED path permissions" |awk '{print $1}'`
    if [ -n "$TRI_LED_COMMIT" ]; then
        git revert --no-edit $TRI_LED_COMMIT
    fi
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
# customization to build opengapps
# ----------------------------------------------------------------------
mkdir device/sony/customization
cat >device/sony/customization/customization.mk <<EOF
GAPPS_VARIANT := pico

GAPPS_PRODUCT_PACKAGES += \\
    Chrome

WITH_DEXPREOPT := true

GAPPS_FORCE_WEBVIEW_OVERRIDES := true
GAPPS_FORCE_BROWSER_OVERRIDES := true

\$(call inherit-product, vendor/opengapps/build/opengapps-packages.mk)
EOF

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

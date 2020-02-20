#!/bin/bash
set -eu

# ----------------------------------------------------------------------
# Variables that can be overriden by caller
# ----------------------------------------------------------------------
SOURCE=${SOURCE:-~/android/source}
APK_DIR=${APK_DIR:-~/android/apk}
LUNCH_CHOICE=${LUNCH_CHOICE:-aosp_g8441-userdebug}
PLATFORM=${PLATFORM:-yoshino}
DEVICE=${DEVICE:-lilac}
# ----------------------------------------------------------------------

_show_help() {
    echo "Usage:"
    echo "  $_shell_script [-b <manifest_branch>] [-h|--help]"
    echo ""
    echo "A script to build AOSP/SODP 10 with linux kernel 4.9 for xperia devices"
    echo ""
    echo "WARNING:"
    echo "  The script is doing terrible things like:"
    echo "  - deleting files"
    echo "  - git hard resets"
    echo "  - git checkouts"
    echo "  therefore the script must not be used in a developers aosp tree with changed files"
    echo "  and/or local commits. Both might get lost when running this script!"
    echo ""
    echo "Options:"
    echo "  -b <manifest_branch>    switches the repo to the specified manifest_branch, e.g. android-10.0.0_r21"
    echo "  -h|--help               display this help"
    echo ""
    echo "Script variables:"
    echo "  SOURCE          AOSP/SODP root folder"
    echo "                  Default: ~/android/source"
    echo "  APK_DIR         currently not used"
    echo "                  Default: ~/android/apk"
    echo "  LUNCH_CHOICE    e.g. aosp_h3113-userdebug, aosp_h9436-userdebug,..."
    echo "                  Default: aosp_g8441-userdebug"
    echo "  PLATFORM        e.g. nile, tama,..."
    echo "                  Default: yoshino"
    echo "  DEVICE          e.g. pioneer, akatsuki,..."
    echo "                  Default: lilac"
    echo ""
    echo "To pass the variables to the script use env, e.g. for pioneer use following command:"
    echo "  env LUNCH_CHOICE=aosp_h3113-userdebug PLATFORM=nile DEVICE=pioneer ./$_shell_script"
}

_pick_pr() {
    local _remote=$1
    local _pr_id=$2
    local _commits=${3:-1}
    local _max_commits=${4:-$_commits}
    local _index=$(($_commits - 1))
    local _count=0

    git fetch $_remote pull/$_pr_id/head

    while [ $_index -ge 0 -a $_count -lt $_max_commits ]; do
        git cherry-pick -Xtheirs --no-edit FETCH_HEAD~$_index
        _index=$(($_index - 1))
        _count=$(($_count + 1))
    done
}

_put_gapps_apk() {
    local _apk_name=$1
    local _target_dir=$2
    local _version=`aapt dump badging $APK_DIR/$_apk_name |grep versionCode=|sed "s#.*versionCode='\([[:digit:]]*\).*#\1#1"`
    mkdir -p $_target_dir
    rm $_target_dir/*
    cp $APK_DIR/$_apk_name $_target_dir/$_version.apk
}

_clean()  {
    pushd .repo/manifests
        git clean -d -f
        git checkout .
        git pull
    popd

    pushd .repo/local_manifests
        _local_manifests_branch=$(git symbolic-ref -q HEAD)
        _local_manifests_branch=${_local_manifests_branch##refs/heads/}
        _local_manifests_branch=${_local_manifests_branch:-HEAD}

        git clean -d -f
        git fetch
        git reset --hard origin/$_local_manifests_branch
    popd

    if [ -d kernel/sony/msm-4.14 ]; then
        rm -r kernel/sony/msm-4.14
    fi

    if [ -d device/sony/customization/ ]; then
        rm -r device/sony/customization
    fi

    for _path in \
        device/sony/$PLATFORM \
        device/sony/common \
        device/sony/sepolicy \
        kernel/sony/msm-4.9/common-kernel \
        kernel/sony/msm-4.9/kernel \
        vendor/opengapps/build \
        vendor/opengapps/sources/all \
        vendor/opengapps/sources/arm \
        vendor/opengapps/sources/arm64 \
        vendor/oss/fingerprint \
        vendor/oss/transpower \
        vendor/qcom/opensource/location
    do
        if [ -d $_path ]; then
            pushd $_path
                git clean -d -f -e "*dtb*"
                git reset --hard m/$_current_branch
            popd
        fi
    done
}

_patch_manifests() {
    pushd .repo/local_manifests
        rm LA.UM.7.1.r1.xml

        # qcom: Switch SM8150 media HAL to LA.UM.8.1.r1 codebase
        git revert --no-edit f9c8739551420d17858387148e7c880e86668a26

        # qcom: Clone legacy media HAL for k4.14 at sdm660-libion
        git revert --no-edit e5a7750a9e5724d2778243d8fb6ce76baec0ef48

        # remove the no-op Android.bp
        git revert --no-edit f2bc4d5e1bfd7d4b48d373350b70dac49c70d2af

        # add display-commonsys-intf git
        git revert --no-edit 52af0a25c9d863179068d912ff1e231639f8de43

        # revert switch display to aosp/LA.UM.7.1.r1
        patch -p1 <<EOF
diff --git a/qcom.xml b/qcom.xml
index 87a3f9c..81964a8 100644
--- a/qcom.xml
+++ b/qcom.xml
@@ -8,8 +8,7 @@

 <project path="hardware/qcom/gps" name="platform/hardware/qcom/sdm845/gps" remote="aosp" groups="qcom_sdm845" />

-<project path="hardware/qcom/display/sde" name="hardware-qcom-display" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" />
-<project path="hardware/qcom/media/sm8150" name="hardware-qcom-media" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" />
+<project path="hardware/qcom/display/sde" name="hardware-qcom-display" groups="device" remote="sony" revision="aosp/LA.UM.7.3.r1" />

 <project path="hardware/qcom/data/ipacfg-mgr/sdm845" name="platform/hardware/qcom/sdm845/data/ipacfg-mgr" groups="qcom_sdm845" remote="aosp" />

@@ -21,7 +20,7 @@
 <project path="vendor/qcom/opensource/telephony" name="vendor-qcom-opensource-telephony" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" />
 <project path="vendor/qcom/opensource/vibrator" name="vendor-qcom-opensource-vibrator" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" />
 <project path="vendor/qcom/opensource/wlan" name="hardware-qcom-wlan" groups="device" remote="sony" revision="master" />
-<project path="vendor/qcom/opensource/interfaces" name="vendor-qcom-opensource-interfaces" groups="device" remote="sony" revision="aosp/LA.UM.7.1.r1" >
-  <linkfile dest="vendor/qcom/opensource/Android.bp" src="os_pickup.bp" />
+<project path="vendor/qcom/opensource/interfaces" name="vendor-qcom-opensource-interfaces" groups="device" remote="sony" revision="aosp/LA.UM.7.3.r1" >
+   <linkfile dest="vendor/qcom/opensource/Android.bp" src="os_pickup.bp" />
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
}

_add_opengapps() {
    pushd .repo/local_manifests

        # ----------------------------------------------------------------------
        # Opengapps
        # ----------------------------------------------------------------------
        cat >opengapps.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="opengapps" fetch="https://github.com/opengapps/" />
  <remote name="opengapps-gitlab" fetch="https://gitlab.opengapps.org/opengapps/" />

  <project path="vendor/opengapps/build" name="aosp_build" revision="master" remote="opengapps" />
  <project path="vendor/opengapps/sources/all" name="all" clone-depth="1" revision="master" remote="opengapps-gitlab" />
  <!-- arm64 depends on arm -->
  <project path="vendor/opengapps/sources/arm" name="arm" clone-depth="1" revision="master" remote="opengapps-gitlab" />
  <project path="vendor/opengapps/sources/arm64" name="arm64" clone-depth="1" revision="master" remote="opengapps-gitlab" />
</manifest>
EOF
    popd
}

_repo_switch() {
    repo sync -j32 --force-sync
    repo init -b $_new_branch

    pushd .repo/local_manifests
        git checkout $_new_branch
    popd
}

_repo_update() {
    ./repo_update.sh
}

_post_update() {
    if [ -d kernel/sony/msm-4.14 ]; then
        rm -r kernel/sony/msm-4.14
    fi

    pushd device/sony/$PLATFORM
        sed -i 's/SOMC_KERNEL_VERSION := .*/SOMC_KERNEL_VERSION := 4.9/1' platform.mk

        # ueventd: Fix Tri-LED path permissions
        _tri_led_commit=`git log --pretty=format:"%H %s"|grep "ueventd: Fix Tri-LED path permissions" |awk '{print $1}'`
        if [ -n "$_tri_led_commit" ]; then
            git revert --no-edit $_tri_led_commit
        fi
    popd

    pushd device/sony/common
        #TEMP: Kernel 4.9 backward compat
        _pick_pr sony 666

        # revert switch to legacy lights
        patch -p1 <<EOF
diff --git a/common-treble.mk b/common-treble.mk
index 44c1f69..09eda13 100644
--- a/common-treble.mk
+++ b/common-treble.mk
@@ -73,13 +73,8 @@ PRODUCT_PACKAGES += \\
     android.hardware.gnss@1.1-service-qti

 # Light
-ifeq (\$(SOMC_KERNEL_VERSION),4.14)
 PRODUCT_PACKAGES += \\
     android.hardware.light@2.0-service.sony
-else
-PRODUCT_PACKAGES += \\
-    android.hardware.light@2.0-service.sony.legacy
-endif

 # Health
 PRODUCT_PACKAGES += \\
EOF

        # remove the no-op Android.bp
        git revert --no-edit fd3e6c8c993d3aa7ef7ae9856d37dc09d4bbcf3f

        # PowerHAL: power-helper: Fix WLAN STATS file path for k4.14
        git revert --no-edit d3cbedf701aa8ab1ed7d571b5fb384665c92df03

        # liblights: Migrate to kernel 4.14 LED class for RGB tri-led
        git revert --no-edit 8b79a2321abe42c9d13540651cbf8a276ec7a2f1

        git fetch https://github.com/MarijnS95/device-sony-common
        # common-packages: Include default thermal hw module.
        git cherry-pick --no-edit bccbb5d57ea6605f7f814e547e46c32257c4b193
    popd

    pushd device/sony/sepolicy
        git fetch https://github.com/MarijnS95/device-sony-sepolicy
        # WIP: Copy hal_thermal_default from crosshatch.
        git cherry-pick --no-edit 6f161dcdb89ad62de58d5ec55ed73bd65e03e54d
    popd

    # ----------------------------------------------------------------------
    # Pull opengapps large files that are stored in git lfs
    # ----------------------------------------------------------------------
    for _path in \
        vendor/opengapps/sources/all \
        vendor/opengapps/sources/arm \
        vendor/opengapps/sources/arm64
    do
        pushd $_path
            git lfs pull opengapps-gitlab &
        popd
    done
    wait

    # ----------------------------------------------------------------------
    # Customization to build opengapps
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
}

_make() {
    set +u # prevent envsetup and lunch from failing because of unset variables
    . build/envsetup.sh
    lunch $LUNCH_CHOICE
    set -u

    make clean

    pushd kernel/sony/msm-4.9/common-kernel
        _platform_upper=`echo $PLATFORM|tr '[:lower:]' '[:upper:]'`
        sed -i "s/PLATFORMS=.*/PLATFORMS=$PLATFORM/1" build-kernels-gcc.sh
        sed -i "s/$_platform_upper=.*/$_platform_upper=$DEVICE/1" build-kernels-gcc.sh
        find . -name "*dtb*" -exec rm "{}" \;
        bash ./build-kernels-gcc.sh
    popd

    make -j`nproc --all`
}

_build() {
    _clean
    _patch_manifests
    _add_opengapps
    _repo_update
    _post_update
    _make
}

_switch_branch() {
    _clean
    _add_opengapps
    _repo_switch
    _build
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
declare _shell_script=${0##*/}
declare _new_branch=""

while (( "$#" )); do
    case $1 in
        -b)
            _new_branch=$2
            shift 2
            ;;
        -h|--help)
            _show_help
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1 for help use $_shell_script -h"
            exit 1
            ;;
    esac
done

cd $SOURCE

_current_branch=`cat .repo/manifest.xml|grep default\ revision|sed 's#^.*refs/tags/\(.*\)"#\1#1'`

if [ -z "$_new_branch" ]; then
    _build
else
    _switch_branch
fi

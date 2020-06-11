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
    echo "  $_shell_script [-b <manifest_branch> [-k|--keep-local]] [-h|--help]"
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
    echo "  -k|--keep-local         keeps the branch for the local manifests repo when switching branches"
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
                git clean -d -f
                git reset --hard m/$_current_branch
            popd
        fi
    done
}

_patch_manifests() {
    pushd .repo/local_manifests
        rm LA.UM.7.1.r1.xml

        # qcom: Switch camera to new HAL.
        _found_commit=`git log --pretty=format:"%H %s"|grep "qcom: Switch camera to new HAL." |awk '{print $1}'`
        if [ -n "$_found_commit" ]; then
            git revert --no-edit $_found_commit
        fi

        # qcom: Switch display interfaces and HAL to LA.UM.8.1.r1 codebase.
        git revert -Xtheirs --no-edit a1f6ee7141059654684c902f34e3c2e2f6fd5595

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

        # device-sony: q-mr1-legacy
        patch -p1 <<EOF
diff --git a/devices.xml b/devices.xml
index ae6fff0..c5fd74b 100644
--- a/devices.xml
+++ b/devices.xml
@@ -1,8 +1,8 @@
 <?xml version="1.0" encoding="UTF-8"?>
 <manifest>
 <remote name="sony" fetch="https://github.com/sonyxperiadev/" />
-<project path="device/sony/sepolicy" name="device-sony-sepolicy" groups="device" remote="sony" revision="master" />
-<project path="device/sony/common" name="device-sony-common" groups="device" remote="sony" revision="master" >
+<project path="device/sony/sepolicy" name="device-sony-sepolicy" groups="device" remote="sony" revision="q-mr1-legacy" />
+<project path="device/sony/common" name="device-sony-common" groups="device" remote="sony" revision="q-mr1-legacy" >
   <linkfile src="misc/no-op/Android.mk" dest="hardware/qcom/sdm845/Android.mk" />
 </project>

EOF

        # ----------------------------------------------------------------------
        # 4.9 kernel-repos
        # ----------------------------------------------------------------------
        cat >LE.UM.2.3.2.r1.4.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
<remote name="sony" fetch="https://github.com/sonyxperiadev/" />
<project path="kernel/sony/msm-4.9/common-headers" name="device-sony-common-headers" groups="device" remote="sony" revision="aosp/LE.UM.2.3.2.r1.4" />
<project path="kernel/sony/msm-4.9/common-kernel" name="kernel-sony-msm-4.9-common" groups="device" remote="sony" revision="aosp/LE.UM.2.3.2.r1.4" clone-depth="1" />
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

    if [ "$_keep_local" = "false" ]; then
        pushd .repo/local_manifests
            git checkout $_new_branch
        popd
    fi
}

_repo_update() {
    ./repo_update.sh
}

_post_update() {
    if [ -d kernel/sony/msm-4.14 ]; then
        rm -r kernel/sony/msm-4.14
    fi

    pushd device/sony/$PLATFORM
        # move sensor config to each platform
        _found_sensor_commit=`git log --pretty=format:"%H %s"|grep "move sensor config to each platform" |awk '{print $1}'`
        if [ -n "$_found_sensor_commit" ]; then
            git revert --no-edit $_found_sensor_commit
        fi

        # ueventd: Fix Tri-LED path permissions
        _found_commit=`git log --pretty=format:"%H %s"|grep "ueventd: Fix Tri-LED path permissions" |awk '{print $1}'`
        if [ -n "$_found_commit" ]; then
            git revert --no-edit $_found_commit
        fi

        sed -i 's/SOMC_KERNEL_VERSION := .*/SOMC_KERNEL_VERSION := 4.9/1' platform.mk
    popd

    pushd device/sony/common
        if [ -n "$_found_sensor_commit" ]; then
            # [q-mr1] Move sensors_settings to platforms
            git revert --no-edit f08af4ce8bb1864c85e3f07cb1d2e3173f89cf66
        fi

        git fetch https://github.com/stefanhh0/device-sony-common q-mr1-legacy
        # common-packages: Include default thermal hw module.
        git cherry-pick --no-edit 9e84337598ccc8d5af56267d448ac5b30b916e30
    popd

    pushd device/sony/sepolicy
        git fetch https://github.com/stefanhh0/device-sony-sepolicy q-mr1-legacy
        # WIP: Copy hal_thermal_default from crosshatch.
        git cherry-pick --no-edit cb62eaecd7b561b3bf83c8240f99c1ea21d151a6
    popd

    pushd hardware/qcom
        if [ -d sm8150 ]; then
            rm -rf sm8150
        fi
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

BOARD_USE_ENFORCING_SELINUX := true
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
        find . -name "*$DEVICE*" -exec rm "{}" \;
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
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
declare _shell_script=${0##*/}
declare _new_branch=""
declare _keep_local="false"

while (( "$#" )); do
    case $1 in
        -b)
            _new_branch=$2
            shift 2
            ;;
        -k|--keep-local)
            _keep_local="true"
            shift
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

if [ -z "$_new_branch" -a "$_keep_local" = "true" ]; then
    echo "-k|--keep-local can only be used with -b"
    echo "For help use $_shell_script -h"
fi

cd $SOURCE

_current_branch=`cat .repo/manifests/default.xml|grep default\ revision|sed 's#^.*refs/tags/\(.*\)"#\1#1'`

if [ -n "$_new_branch" ]; then
    _switch_branch
fi

_build

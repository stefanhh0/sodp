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
    echo "A script to build AOSP/SODP 10 with linux kernel 4.14 for xperia devices"
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
    if [ -d kernel/sony/msm-4.9 ]; then
        rm -r kernel/sony/msm-4.9
    fi

    if [ -d hardware/qcom/sdm845 ]; then
        rm -r hardware/qcom/sdm845
    fi

    if [ -d device/sony/customization/ ]; then
        rm -r device/sony/customization
    fi

    for _path in \
        device/sony/$PLATFORM \
        device/sony/common \
        device/sony/sepolicy \
        kernel/sony/msm-4.14/common-kernel \
        kernel/sony/msm-4.14/kernel \
        vendor/opengapps/build \
        vendor/opengapps/sources/all \
        vendor/opengapps/sources/arm \
        vendor/opengapps/sources/arm64 \
        vendor/oss/transpower
    do
        if [ -d $_path ]; then
            pushd $_path
                git clean -d -f -e "*dtb*"
                git reset --hard m/$_current_branch
            popd
        fi
    done
}

_clean_manifests() {
    pushd .repo/manifests
        git clean -d -f
        git checkout .
        git pull
    popd

    pushd .repo/local_manifests
        git clean -d -f
        git fetch
        git reset --hard origin/$_current_branch
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
    pushd device/sony/common
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

    for _compiler in gcc clang; do
        pushd kernel/sony/msm-4.14/common-kernel
            _platform_upper=`echo $PLATFORM|tr '[:lower:]' '[:upper:]'`
            sed -i "s/PLATFORMS=.*/PLATFORMS=$PLATFORM/1" build-kernels-${_compiler}.sh
            sed -i "s/$_platform_upper=.*/$_platform_upper=$DEVICE/1" build-kernels-${_compiler}.sh
            find . -name "*dtb*" -exec rm "{}" \;
            bash ./build-kernels-${_compiler}.sh
        popd

        make -j`nproc --all` bootimage

        pushd out/target/product/$DEVICE
            cp -a boot.img boot-${_compiler}.img
        popd
    done

    make -j`nproc --all`
}

_build() {
    _clean
    _clean_manifests
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

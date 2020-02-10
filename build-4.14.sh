#!/bin/bash
set -e

# ----------------------------------------------------------------------
# Variables that can be overriden by caller
# ----------------------------------------------------------------------
SOURCE=${SOURCE:-~/android/source}
APK_DIR=${APK_DIR:-~/android/apk}
LUNCH_CHOICE=${LUNCH_CHOICE:-aosp_g8441-userdebug}
PLATFORM=${PLATFORM:-yoshino}
DEVICE=${DEVICE:-lilac}
# ----------------------------------------------------------------------

_pick_pr() {
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

_put_gapps_apk() {
    local APK_NAME=$1
    local TARGET_DIR=$2
    local VERSION=`aapt dump badging $APK_DIR/$APK_NAME |grep versionCode=|sed "s#.*versionCode='\([[:digit:]]*\).*#\1#1"`
    mkdir -p $TARGET_DIR
    rm $TARGET_DIR/*
    cp $APK_DIR/$APK_NAME $TARGET_DIR/$VERSION.apk
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

    for path in \
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
        if [ -d $path ]; then
            pushd $path
                git clean -d -f -e "*dtb*"
                git reset --hard m/$ANDROID_VERSION
            popd
        fi
    done
}

_patch_manifests() {
    # ----------------------------------------------------------------------
    # Manifest adjustments
    # ----------------------------------------------------------------------
    pushd .repo/manifests
        git clean -d -f
        git checkout .
        git pull
    popd

    # ----------------------------------------------------------------------
    # Local manifest adjustments
    # ----------------------------------------------------------------------
    pushd .repo/local_manifests
        git clean -d -f
        git fetch
        git reset --hard origin/$ANDROID_VERSION

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
    for path in \
        vendor/opengapps/sources/all \
        vendor/opengapps/sources/arm \
        vendor/opengapps/sources/arm64
    do
        pushd $path
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

    _put_gapps_apk TrichromeLibraryPlayStore.apk vendor/opengapps/sources/arm64/app/com.google.android.trichromelibrary/29/nodpi
}

_build() {
    . build/envsetup.sh
    lunch $LUNCH_CHOICE

    make clean

    for COMPILER in gcc clang; do
        pushd kernel/sony/msm-4.14/common-kernel
            PLATFORM_UPPER=`echo $PLATFORM|tr '[:lower:]' '[:upper:]'`
            sed -i "s/PLATFORMS=.*/PLATFORMS=$PLATFORM/1" build-kernels-${COMPILER}.sh
            sed -i "s/$PLATFORM_UPPER=.*/$PLATFORM_UPPER=$DEVICE/1" build-kernels-${COMPILER}.sh
            find . -name "*dtb*" -exec rm "{}" \;
            bash ./build-kernels-${COMPILER}.sh
        popd

        make -j`nproc --all` bootimage

        pushd out/target/product/$DEVICE
            cp -a boot.img boot-${COMPILER}.img
        popd
    done

    make -j`nproc --all`
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
cd $SOURCE

ANDROID_VERSION=`cat .repo/manifest.xml|grep default\ revision|sed 's#^.*refs/tags/\(.*\)"#\1#1'`

_clean
_patch_manifests
_repo_update
_post_update
_build

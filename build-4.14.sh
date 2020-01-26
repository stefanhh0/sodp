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
+  <project path="vendor/opengapps/sources/all" name="all" clone-depth="1" revision="master" remote="gitlab" />
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
popd

./repo_update.sh

pushd device/sony/common
    git fetch https://github.com/MarijnS95/device-sony-common
    # common-packages: Include default thermal hw module.
    git cherry-pick --no-edit d74ebb45e1783fdd1e757faa2abcb626b34489f5
popd

pushd device/sony/sepolicy
    git fetch https://github.com/MarijnS95/device-sony-sepolicy
    # WIP: Copy hal_thermal_default from crosshatch.
    git cherry-pick --no-edit 2974bc6a5497c945a72df3882bc032aa741ce443
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

pushd kernel/sony/msm-4.14/common-kernel
    PLATFORM_UPPER=`echo $PLATFORM|tr '[:lower:]' '[:upper:]'`
    sed -i "s/PLATFORMS=.*/PLATFORMS=$PLATFORM/1" build-kernels-gcc.sh
    sed -i "s/$PLATFORM_UPPER=.*/$PLATFORM_UPPER=$DEVICE/1" build-kernels-gcc.sh
    find . -name "*dtb*" -exec rm "{}" \;
    bash ./build-kernels-gcc.sh
popd

make -j`nproc --all`

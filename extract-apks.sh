#!/bin/bash
set -e

# ----------------------------------------------------------------------
# URL: https://developers.google.com/android/images
# Variables have to be adjusted accordingly
# ----------------------------------------------------------------------
APK=~/android/q
IMAGE_NAME=crosshatch-qq1a.191205.008-factory-ff62c022.zip
DOWNLOAD_DIR=~/android/crosshatch
# ----------------------------------------------------------------------

IMAGE_FILE=$DOWNLOAD_DIR/$IMAGE_NAME

if [ ! -d $DOWNLOAD_DIR ]; then
    mkdir $DOWNLOAD_DIR
fi

if [ ! -f $IMAGE_FILE ]; then
    pushd $DOWNLOAD_DIR
    wget https://dl.google.com/dl/android/aosp/$IMAGE_NAME
    popd
fi

TMP=/tmp/`basename $IMAGE_NAME .zip`
if [ -d $TMP ]; then
    rm -r $TMP
fi
mkdir $TMP

pushd $TMP
unzip -p $IMAGE_FILE "*/image*" >image.zip
unzip image.zip product.img system.img

simg2img product.img product.raw
mkdir product
sudo mount -o ro product.raw product

simg2img system.img system.raw
mkdir system
sudo mount -o ro system.raw system

cp -v ./system/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk $APK
cp -v ./system/system/priv-app/GooglePermissionControllerPrebuilt/GooglePermissionControllerPrebuilt.apk $APK
cp -v ./product/priv-app/SetupWizardPrebuilt/SetupWizardPrebuilt.apk $APK
cp -v ./product/app/TrichromeLibrary/TrichromeLibrary.apk $APK

sudo umount product
sudo umount system
popd

rm -r $TMP

echo "Finished successfully."
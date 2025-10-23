#!/bin/bash

# Default values
INCLUDE_PRELOADER=true
URL=""

# Argument handler
for arg in "$@"; do
  case $arg in
    --no-preloader)
      INCLUDE_PRELOADER=false
      shift
      ;;
    --url | -u)
      if [[ $# -gt 0 ]]; then
        URL="$2"
        shift 2
      else
        echo "Error: --url requires a URL argument"
        exit 1
      fi
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

aria2c -s16 -x16 -o archive "$URL"

if ! file archive | grep -qi 'zip'; then
  echo "Not a zip file, abort"
  exit 1
fi

FW_DIR="$PWD/fw"
mkdir -p $FW_DIR

unzip -q archive payload.bin -d $FW_DIR

cd $FW_DIR
if ! [ -f payload.bin ]; then
  echo "payload.bin does not exist"
  cd $OLDPWD
  exit 1
fi
wget -q https://github.com/tobyxdd/android-ota-payload-extractor/releases/download/v1.1/android-ota-extractor-v1.1-linux-amd64.tar.gz
tar -xf android-ota-extractor-v1.1-linux-amd64.tar.gz
if ! [ -f android-ota-extractor ]; then
  echo "android-ota-extractor doesnt exist."
  cd $OLDPWD
  exit 1
else
  sudo mv android-ota-extractor /usr/bin
  sudo chmod 0755 /usr/bin/android-ota-extractor
fi

android-ota-extractor payload.bin
rm -f payload.bin

KNOWN_DYNAMIC_PARTITION=(
  system
  system_ext
  system_dlkm
  vendor
  vendor_dlkm
  odm_dlkm
  product
  mi_ext
)

mkdir -p dynamic
mkdir -p firmware

for p in ${KNOWN_DYNAMIC_PARTITION[@]}; do
  mv -f "$p".img dynamic
done

mv -f *.img firmware
if ! $INCLUDE_PRELOADER; then
  rm -f firmware/preloader*.img
fi

for p in $(ls dynamic); do
  echo "${p//.img/} $(wc -c < dynamic/$p) /dev/block/mapper/${p//.img/}"
done > dynamic.txt

ls firmware > firmware.txt

cd $OLDPWD

git clone --depth=1 https://github.com/linastorvaldz/jembod jmbd && cd jmbd
rm -f dynamic-partitions/*
rm -f firmware-images/*

mv $FW_DIR/dynamic.txt ./dynamic_transfer_list.txt
mv $FW_DIR/firmware.txt ./other_transfer_list.txt

mv $FW_DIR/dynamic/* ./dynamic-partitions
mv $FW_DIR/firmware/* ./firmware-images

rm -rf $FW_DIR

echo
echo -n "Device name: "
read dev
echo -n "OS Version: "
read os_ver
echo

sed -i "s/divais/\"$dev\"/g" info.sh
sed -i "s/ngentot/\"$os_ver\"/g" info.sh

ZIP_NAME="FLASHABLE-$dev-$os_ver.zip"

zip -r9 $OLDPWD/$ZIP_NAME *

cd $OLDPWD

ls -lh $ZIP_NAME

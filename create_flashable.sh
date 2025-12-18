#!/bin/bash
set -euo pipefail

# Default values
INCLUDE_PRELOADER=true
URL=""

# --- Argument handler ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-preloader)
      INCLUDE_PRELOADER=false
      shift
      ;;
    --url | -u)
      if [[ -n "${2:-}" ]]; then
        URL="$2"
        shift 2
      else
        echo "Error: --url requires a URL argument" >&2
        exit 1
      fi
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$URL" ]]; then
  echo "Error: no URL provided. Use --url <link>" >&2
  exit 1
fi

# --- Download firmware ---
aria2c -s16 -x16 -o archive "$URL"

# --- Prepare workspace ---
WORKDIR="$PWD"
FW_DIR="$WORKDIR/fw"
mkdir -p "$FW_DIR"

unzip -qo archive payload.bin -d "$FW_DIR" || {
  echo "Failed to un-zip the firmware archive!"
  exit 1
}

cd "$FW_DIR"

if [[ ! -f payload.bin ]]; then
  echo "payload.bin not found!"
  exit 1
fi

# --- Extract payload.bin ---
EXTRACTOR_URL="https://github.com/tobyxdd/android-ota-payload-extractor/releases/download/v1.1/android-ota-extractor-v1.1-linux-amd64.tar.gz"

wget -q "$EXTRACTOR_URL" -O extractor.tar.gz
tar -xf extractor.tar.gz
rm -f extractor.tar.gz

if [[ ! -f android-ota-extractor ]]; then
  echo "android-ota-extractor binary missing!"
  exit 1
fi

chmod +x android-ota-extractor
sudo mv -f android-ota-extractor /usr/local/bin/

android-ota-extractor payload.bin
rm -f payload.bin

# --- Organize images ---
KNOWN_DYNAMIC_PARTITION=(
  system system_ext system_dlkm vendor vendor_dlkm
  odm_dlkm product mi_ext
)

mkdir -p dynamic firmware

for p in "${KNOWN_DYNAMIC_PARTITION[@]}"; do
  [[ -f "$p.img" ]] && mv -f "$p.img" dynamic/
done

# Move remaining .img files to firmware/
shopt -s nullglob
for img in *.img; do
  mv -f "$img" firmware/
done
shopt -u nullglob

# Optionally remove preloader
if ! $INCLUDE_PRELOADER; then
  rm -f firmware/preloader*.img
fi

# --- Generate partition list ---
{
  for p in dynamic/*.img; do
    bn=$(basename "$p" .img)
    size=$(wc -c < "$p")
    echo "$bn $size /dev/block/mapper/$bn"
  done
} > dynamic.txt

ls firmware > firmware.txt

cd "$WORKDIR"

# --- Clone and organize target repo ---
git clone --depth=1 https://github.com/linastorvaldz/jembod jmbd
cd jmbd

rm -rf dynamic-partitions/* firmware-images/*

mv "$FW_DIR/dynamic.txt" ./dynamic_transfer_list.txt
mv "$FW_DIR/firmware.txt" ./other_transfer_list.txt
mv "$FW_DIR/dynamic"/* ./dynamic-partitions/
mv "$FW_DIR/firmware"/* ./firmware-images/
rm -rf "$FW_DIR"

# --- Input device info ---
echo
read -rp "Device name: " dev
read -rp "OS Version: " os_ver
echo

# --- Update info.sh placeholders ---
sed -i "s/divais/\"$dev\"/g" info.sh
sed -i "s/ngentot/\"$os_ver\"/g" info.sh

# --- Create flashable ZIP ---
ZIP_NAME="FLASHABLE-${dev}-${os_ver}.zip"
zip -r9 "$WORKDIR/$ZIP_NAME" ./* > /dev/null

cd "$WORKDIR"
ls -lh "$ZIP_NAME"

echo
echo "✅ Flashable zip created successfully: $ZIP_NAME"

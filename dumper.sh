#!/bin/bash
#set -eo pipefail

bin="$PWD/bin"
if ! [ -d "$bin" ]; then
  mkdir $bin
  wget -q https://raw.githubusercontent.com/ramabondanp/DumprX/refs/heads/main/utils/lpunpack \
    -O $bin/lpunpack
  wget -q https://raw.githubusercontent.com/ramabondanp/DumprX/refs/heads/main/utils/bin/simg2img \
    -O $bin/simg2img
  wget -q https://github.com/sekaiacg/erofs-utils/releases/download/v1.8.10-250719/erofs-utils-v1.8.10-g0e284fcb-Linux_x86_64-2507191652.zip \
    -O erofs-utils.zip
  unzip -q erofs-utils.zip -d $bin
  rm -f erofs-utils.zip
  wget -q https://github.com/tobyxdd/android-ota-payload-extractor/releases/download/v1.1/android-ota-extractor-v1.1-linux-amd64.tar.gz
    -O ota-extractor.zip
  unzip -q ota-extractor -d $bin
  rm -f ota-extractor.zip
  chmod a+x $bin/*
fi

extract_payload() {
  ${bin}/android-ota-payload-extractor $@
  return $?
}

extract_erofs() {
  local img
  for img in $@; do
    if [ -z "$img" ]; then
      echo "error: an erofs image is needed."
      return 1
    elif [ ! -f "$img" ]; then
      echo "error: file is not found."
      return 1
    fi
    ${bin}/extract.erofs -i "$img" -x -T8 -o .
    rm -rf config
  done
}

extract_partition_from_super() {
  local p
  $bin/simg2img super.img super.img.raw

  for p in $@; do
    $bin/lpunpack --partition="${p}_a" super.img.raw \
      || $bin/lpunpack --partition="$p" super.img.raw
    if [ -f "${p}_a.img" ]; then
      mv -f "${p}_a.img" "$p.img"
    fi
  done
  rm -f super.img.raw
}

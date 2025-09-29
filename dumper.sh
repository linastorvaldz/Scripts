#!/bin/bash
set -eo pipefail

bin="$PWD/bin"
if ! [ -d "$bin" ]; then
    mkdir $bin
    wget https://raw.githubusercontent.com/ramabondanp/DumprX/refs/heads/main/utils/lpunpack \
      -O $bin/lpunpack
    wget https://raw.githubusercontent.com/ramabondanp/DumprX/refs/heads/main/utils/bin/simg2img \
      -O $bin/simg2img
    wget https://github.com/sekaiacg/erofs-utils/releases/download/v1.8.10-250719/erofs-utils-v1.8.10-g0e284fcb-Linux_x86_64-2507191652.zip \
      -O erofs-utils.zip
    unzip -q erofs-utils.zip -d $bin
    rm -f erofs-utils.zip
fi
    
extract_erofs() {
    local img="$1"

    if [ -z "$img" ] || [ ! -f "$img" ]; then
        echo "error: an erofs image is needed."
        exit 1
    fi
    
    ${bin}/extract.erofs -i "$img" -x -T8 -o .
    rm -rf config
}

extract_partition_from_super() {
    local superimg="$1"
    local target_partition="$2"

    $bin/simg2img $superimg super.img.raw
    $bin/lpunpack --partition="${target_partition}_a" || $bin/lpunpack --partition="$target_partition" super.img.raw
    if [ -f "${target_partition}_a.img" ]; then
        mv -f "${target_partition}_a.img" "$target_partition.img"
    fi
    
    rm -f super.img.raw
}

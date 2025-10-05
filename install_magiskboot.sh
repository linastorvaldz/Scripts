#!/usr/bin/env bash
set -e

get_latest_magiskbins() {
  local url="$1"
  local grp_expr="$2"
  [[ -z "$grp_expr" ]] && grp_expr=".7z"
  curl -s "$url" | grep "browser_download_url" | grep "$grp_expr" | cut -d '"' -f 4 | head -n1
  return $?
}

install_magiskboot() {
  local arch
  local magiskboot_f
  local magiskboot_install
  arch="$1"
  magiskboot_install="$PREFIX/bin"
  [ -z "$arch" ] && echo "arch must be specified!" && return 1
  magiskboot_f="native/out/$arch/magiskboot"
  [ -f "$magiskboot_f" ] || echo "magiskboot for $arch arch is not found." && return 1
  sudo cp $magiskboot_f $magiskboot_install || echo "failed to copy magiskboot into $magiskboot_install."
  magiskboot --help > /dev/null 2>&1 || echo "failed to execute magiskboot" && return 1
  return
}

MAGISKBINS_REPO="https://api.github.com/repos/xiaoxindada/magisk_bins_ndk/releases/latest"
MAGISKBINS_URL=$(get_latest_magiskbins "$MAGISKBINS_REPO")

# download magisk bins
curl -s "$MAGISKBINS_URL" -o magiskbins.7z

# extract the magisk bins archive
7z x magiskbins.7z

# determine architecture
case "$(uname -m)" in
  "x86_64") arch="x86_64" ;;
  "aarch64") arch="arm64-v8a" ;;
  "i686") arch="x86" ;;
  *) arch="armeabi-v7a" ;;
esac

# install the magiskboot
install_magiskboot "$arch"

# cleanup
rm -rf native magiskbins.7z

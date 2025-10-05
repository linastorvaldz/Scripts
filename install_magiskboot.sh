#!/usr/bin/env bash
set -e

# === Config ===
MAGISKBINS_REPO="https://api.github.com/repos/xiaoxindada/magisk_bins_ndk/releases/latest"
TMPDIR="$(mktemp -d)"
INSTALL_DIR="${PREFIX:-/usr}/bin"

# === Functions ===
die() {
  echo -e "\e[31m[ERROR]\e[0m $*" >&2
  exit 1
}

info() {
  echo -e "\e[34m[*]\e[0m $*"
}

check_deps() {
  local deps=("curl" "7z" "sudo")
  for dep in "${deps[@]}"; do
    command -v "$dep" >/dev/null 2>&1 || die "Dependency '$dep' not found!"
  done
}

get_latest_magiskbins() {
  local url="$1"
  local grep_expr="${2:-.7z}"
  local result
  result=$(curl -s "$url" | grep "browser_download_url" | grep "$grep_expr" | cut -d '"' -f 4 | head -n1)
  [[ -n "$result" ]] || die "Failed to get Magisk binaries download URL!"
  echo "$result"
}

install_magiskboot() {
  local arch="$1"
  [[ -z "$arch" ]] && die "Architecture must be specified!"
  local magiskboot_f="$TMPDIR/native/out/$arch/magiskboot"
  [[ -f "$magiskboot_f" ]] || die "magiskboot binary for '$arch' not found in extracted archive!"
  
  info "Installing magiskboot to $INSTALL_DIR"
  sudo install -m 755 "$magiskboot_f" "$INSTALL_DIR/magiskboot" || die "Failed to install magiskboot!"
  
  if ! "$INSTALL_DIR/magiskboot" --help >/dev/null 2>&1; then
    die "Installed magiskboot failed to execute properly!"
  fi
  info "magiskboot successfully installed and verified."
}

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# === Main ===
check_deps

info "Fetching latest Magisk binaries..."
MAGISKBINS_URL="$(get_latest_magiskbins "$MAGISKBINS_REPO")"
info "Download URL: $MAGISKBINS_URL"

cd "$TMPDIR"
info "Downloading Magisk binaries..."
curl -L -s "$MAGISKBINS_URL" -o magiskbins.7z || die "Failed to download Magisk bins."

set +e
info "Extracting archive..."
7z x -y magiskbins.7z >/dev/null 2>&1
set -e

info "Detecting architecture..."
case "$(uname -m)" in
  x86_64) arch="x86_64" ;;
  aarch64) arch="arm64-v8a" ;;
  i686) arch="x86" ;;
  armv7l|armv8l) arch="armeabi-v7a" ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
esac
info "Detected architecture: $arch"

install_magiskboot "$arch"

info "Cleanup temporary files..."
cleanup

info "✅ Done! magiskboot installed at: $INSTALL_DIR/magiskboot"


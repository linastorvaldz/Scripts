#!/bin/bash
set -euo pipefail

ROOT="$(realpath $(dirname "$0"))"
KSU_PATCHES_DIR="$ROOT/ksu-patches"

die() {
  echo "error: $*" >&2
  exit 1
}

add_gitignore() {
  local f
  for f in '*.patch' '*.rej' '*.orig' '.kp' '.susfs'; do
    grep -qxF "$f" .gitignore 2>/dev/null || echo "$f" >> .gitignore
  done
}

cleanup_tree() {
  shopt -s dotglob
  for f in *; do
    case "$f" in
      .git|kernel|LICENSE|.gitignore) ;;
      *) rm -rf -- "$f" ;;
    esac
  done
  shopt -u dotglob
}

check_dep() {
  local dir="$1" repo="$2" branch="$3"

  if [ -d "$dir/.git" ]; then
    echo "📥 Updating $dir..."
    git -C "$dir" pull
  else
    echo "📥 Cloning $repo ($branch)"
    git clone --depth=1 -b "$branch" "$repo" "$dir"
  fi
}

### setup ###
add_gitignore
cleanup_tree

git add .
git commit -sm "Cleanup"

### deps ###
check_dep ".susfs" "https://gitlab.com/simonpunk/susfs4ksu" "gki-android12-5.10"
check_dep ".kp" "https://github.com/WildKernels/kernel_patches" "main"

sus_dir="$PWD/.susfs"
sus_ver="$(
  sed -n 's/^#define[[:space:]]\+SUSFS_VERSION[[:space:]]\+"\([^"]\+\)"/\1/p' \
  "$sus_dir/kernel_patches/include/linux/susfs.h"
)"

[ -n "$sus_ver" ] || die "Failed to detect SUSFS_VERSION"

kp="$PWD/.kp/next/susfs_fix_patches/$sus_ver"
sus_patch="$sus_dir/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"

[ -d kernel ] || die "kernel directory not found"
[ -d "$kp" ] || die "susfs fix patches are not available for ${sus_ver}!"

### apply base patch ###
patch -p1 < "$sus_patch"

### apply fix patches ###
while IFS= read -r rej; do
  base="$(basename "$rej" .rej)"
  fix="$kp/fix_${base}.patch"

  [ -f "$fix" ] || die "Missing fix patch: $fix"
  patch -p1 < "$fix"
  echo "✔ fixed $base"
done < <(find kernel -name '*.rej')

### apply KSU patches ###
for p in "$KSU_PATCHES_DIR"/*.patch; do
  echo "📌 Applying $(basename "$p")"
  if ! git am "$p"; then
    if ! patch -p1 < "$p"; then
      die "Failed to apply $(basename "$p"), please fix it manually."
    fi
    git add .
    git am --continue
  fi
done

### cleanup ###
find . -type f \( -name '*.rej' -o -name '*.orig' \) -delete

git add .
git commit -sm "Apply kernelsu-side susfs ${sus_ver} patches"

#!/usr/bin/env bash

# setup .gitignore
echo '.*' > .gitignore
git add .gitignore
git commit -sm "Prepare" || true

# cleanup (kecuali .git, kernel, LICENSE, .gitignore)
shopt -s dotglob
for f in *; do
    case "$f" in
        .git|kernel|LICENSE|.gitignore) ;;
        *) rm -rf "$f" ;;
    esac
done
shopt -u dotglob
git add -A
git commit -sm "Cleanup." || true

# change repo link
target_repo="fastbooteraseboot/KernelSU-Next"
sed -i "s|KernelSU-Next/KernelSU-Next|$target_repo|g" kernel/setup.sh
git add kernel/setup.sh
git commit -sm "setup.sh: switch to our fork"

# functions
check() {
    local dir="$1"
    local repo="$2"
    local branch="$3"

    if [ -d "$dir/.git" ]; then
        echo "📥 Updating $dir..."
        git -C "$dir" pull --ff-only || true
    else
        echo "📥 Cloning $repo ($branch) into $dir..."
        git clone --depth=1 -b "$branch" "$repo" "$dir"
    fi
}

abort() {
    echo "❌ error: $*" >&2
    exit 1
}

_patch() {
    local patch_file="$1"
    patch -p1 --no-backup-if-mismatch <"$patch_file"

    # cleanup .orig / .rej
    find . -type f \( -name '*.orig' -o -name '*.rej' \) -delete
}

# clone repos
check ".susfs" "https://gitlab.com/simonpunk/susfs4ksu" "gki-android15-6.6"
check ".kp" "https://github.com/WildKernels/kernel_patches" "main"

sus_dir="$PWD/.susfs"
sus_ver=$(grep -E '^#define SUSFS_VERSION' \
    "$sus_dir/kernel_patches/include/linux/susfs.h" | \
    cut -d' ' -f3 | tr -d '"')

kp="$PWD/.kp/next/susfs_fix_patches/$sus_ver"
sus_patch="${sus_dir}/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"

[ -d "kernel" ] || abort "kernel directory not found."
[ -d "$kp" ] || abort "susfs fix patches directory not found"

# start patching
_patch "$sus_patch"

for p in "$kp"/*.patch; do
    _patch "$p"
done

git add -A
git commit -sm "Add SUSFS $sus_ver" || true

echo "🎉 Done! SUSFS $sus_ver applied successfully."


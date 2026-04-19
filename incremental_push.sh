#!/usr/bin/env bash
set -euo pipefail

BRANCH_NAME="${1:-$(git rev-parse --abbrev-ref HEAD)}"
REMOTE_NAME="${2:-origin}"
STEP_SIZE="${3:-1000}"

echo "[INFO] Mengambil daftar commit dari branch '$BRANCH_NAME'..."

# Cek commit terakhir yang sudah ada di remote (untuk resume)
REMOTE_HEAD=$(git ls-remote "$REMOTE_NAME" "refs/heads/$BRANCH_NAME" | awk '{print $1}')

if [[ -n "$REMOTE_HEAD" ]]; then
  echo "[INFO] Remote sudah ada di $REMOTE_HEAD, hanya push sisanya..."
  RANGE="$REMOTE_HEAD..refs/heads/$BRANCH_NAME"
else
  RANGE="refs/heads/$BRANCH_NAME"
fi

# Ambil commit dengan step, pakai --first-parent agar linear
step_commits=$(git log --oneline --reverse --first-parent "$RANGE" \
  | awk "NR % $STEP_SIZE == 0" | awk '{print $1}')

if [[ -z "$step_commits" ]]; then
  echo "[INFO] Tidak ada commit baru, langsung final push..."
else
  for commit in $step_commits; do
    echo "  → Push s/d commit $commit"
    git push "$REMOTE_NAME" "+$commit:refs/heads/$BRANCH_NAME" || {
      echo "[ERROR] Gagal di commit $commit"
      exit 1
    }
  done
fi

# Final push — hanya branch ini, BUKAN --mirror
echo "[INFO] Final push branch '$BRANCH_NAME'..."
git push "$REMOTE_NAME" "refs/heads/$BRANCH_NAME"

echo "[OK] Incremental push selesai ✅"

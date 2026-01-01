#!/usr/bin/env bash
set -euo pipefail

# ============================
# Config (bisa juga via argumen)
# ============================
BRANCH_NAME="${1:-$(git rev-parse --abbrev-ref HEAD)}" # arg1 atau current branch
REMOTE_NAME="${2:-origin}"                             # arg2 atau origin
STEP_SIZE="${3:-200000}"                               # arg3 atau default 1000

# ============================
# Step 1: Ambil setiap nth commit
# ============================
echo "[INFO] Mengambil daftar commit dari branch '$BRANCH_NAME'..."
step_commits=$(git log --oneline --reverse "refs/heads/$BRANCH_NAME" \
  | awk "NR % $STEP_SIZE == 0" | awk '{print $1}')

if [[ -z "$step_commits" ]]; then
  echo "[ERROR] Tidak ada commit yang cocok. Coba turunkan STEP_SIZE."
  exit 1
fi

# ============================
# Step 2: Push commit bertahap
# ============================
echo "[INFO] Memulai incremental push ke '$REMOTE_NAME/$BRANCH_NAME' dengan step $STEP_SIZE commit..."
for commit in $step_commits; do
  echo "  → Push commit $commit"
  if ! git push "$REMOTE_NAME" "+$commit:refs/heads/$BRANCH_NAME"; then
    echo "[ERROR] Gagal push commit $commit. Keluar."
    exit 1
  fi
done

# ============================
# Step 3: Final sync
# ============================
echo "[INFO] Final sync semua ref..."
git push "$REMOTE_NAME" --mirror

echo "[OK] Incremental push selesai ✅"

#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

apply_once() {
  local checkout="$1" patch="$2"
  if git -C "$checkout" apply --reverse --check "$patch" 2>/dev/null; then
    echo "Already applied: $(basename "$patch")"
  else
    git -C "$checkout" apply --check "$patch"
    git -C "$checkout" apply "$patch"
    echo "Applied: $(basename "$patch")"
  fi
}

apply_once "$root/dependencies/QuestTelePanthera" "$root/patches/quest-install.patch"
if [[ "${1:-}" == "--with-lerobot" ]]; then
  apply_once "$root/dependencies/Panthera-HT_lerobot" "$root/patches/lerobot-utm-compat.patch"
fi

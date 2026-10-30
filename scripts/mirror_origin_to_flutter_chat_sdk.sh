#!/usr/bin/env bash
# Mirrors every origin remote-tracking branch to the FlutterChatSdk remote.
# Reuse: run from repo root after GitHub auth works (SourceTree account or gh auth).
# Uses force (+) so remote branches match origin/* (restore/mirror workflow).
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

DEST_REMOTE="${1:-FlutterChatSdk}"
BATCH_SIZE="${2:-15}"

if ! git remote get-url "$DEST_REMOTE" >/dev/null 2>&1; then
  echo "Remote not found: $DEST_REMOTE" >&2
  exit 1
fi

branches=()
while IFS= read -r branch; do
  [[ -z "$branch" || "$branch" == "HEAD" ]] && continue
  branches+=("$branch")
done < <(git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/)

if ((${#branches[@]} == 0)); then
  echo "No origin/* refs found. Run: git fetch origin" >&2
  exit 1
fi

echo "Pushing ${#branches[@]} origin/* refs to $DEST_REMOTE..."
ok=0
fail=0
batch=()

push_batch() {
  ((${#batch[@]} == 0)) && return 0
  if git push "$DEST_REMOTE" "${batch[@]}"; then
    ok=$((ok + ${#batch[@]}))
  else
    echo "Batch push failed; retrying branches individually..." >&2
    for spec in "${batch[@]}"; do
      if git push "$DEST_REMOTE" "${spec}"; then
        ok=$((ok + 1))
      else
        echo "  FAILED: $spec" >&2
        fail=$((fail + 1))
      fi
    done
  fi
  batch=()
}

for branch in "${branches[@]}"; do
  batch+=("+refs/remotes/origin/${branch}:refs/heads/${branch}")
  if ((${#batch[@]} >= BATCH_SIZE)); then
    push_batch
  fi
done
push_batch

echo "Branch refs OK: $ok, failed: $fail"
echo "Pushing tags..."
git push "$DEST_REMOTE" --tags || echo "Tag push had errors (see above)." >&2

git fetch "$DEST_REMOTE" --prune
remote_count="$(git branch -r | grep -c " ${DEST_REMOTE}/" || true)"
echo "Remote tracking branches on $DEST_REMOTE: $remote_count"

((${fail} > 0)) && exit 1
echo "Done."

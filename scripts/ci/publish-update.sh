#!/bin/sh
# Run against a dedicated checkout of the current default branch.
set -eu
metadata=$1
checkout=$2
branch=$3
tag=$4

git -C "$checkout" config user.name 'github-actions[bot]'
git -C "$checkout" config user.email '41898282+github-actions[bot]@users.noreply.github.com'
for attempt in 1 2 3; do
  git -C "$checkout" fetch --quiet origin "$branch"
  git -C "$checkout" checkout --quiet -B "$branch" FETCH_HEAD
  decision=$(python3 - "$metadata" "$checkout/update.json" <<'PYCODE'
import json
from pathlib import Path
import sys
new = json.loads(Path(sys.argv[1]).read_text())
try:
    old = json.loads(Path(sys.argv[2]).read_text())
    old_code = int(old["versionCode"])
except (OSError, ValueError, KeyError, TypeError):
    old_code = 0
print("skip" if int(new["versionCode"]) < old_code else "publish")
PYCODE
  )
  if [ "$decision" = skip ]; then
    echo 'A newer stable version is already advertised; keeping its metadata'
    exit 0
  fi
  cp "$metadata" "$checkout/update.json"
  git -C "$checkout" add update.json
  if git -C "$checkout" diff --cached --quiet; then
    echo 'Updater metadata already matches this release'
    exit 0
  fi
  git -C "$checkout" -c commit.gpgsign=false commit -m "Update update.json for $tag"
  if git -C "$checkout" push origin "HEAD:$branch"; then
    exit 0
  fi
  if [ "$attempt" -lt 3 ]; then sleep 2; fi
done
echo 'Failed to publish updater metadata after three attempts' >&2
exit 1

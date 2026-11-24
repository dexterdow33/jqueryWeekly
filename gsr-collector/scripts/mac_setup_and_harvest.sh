#!/usr/bin/env bash
# One-shot setup + harvest + Drive sync on a Mac. Safe to re-run.
#
#   curl -fsSLo ~/Downloads/gsr_setup.sh https://raw.githubusercontent.com/dexterdow33/jqueryWeekly/claude/gsr-collector/gsr-collector/scripts/mac_setup_and_harvest.sh
#   bash ~/Downloads/gsr_setup.sh
# (Download first, don't pipe into bash: the one-time Drive login needs the keyboard.)
#
# What it does, in ~/Documents/GSR (override with GSR_DIR=...):
#   1. installs rclone with Homebrew if missing
#   2. clones or updates the collector (branch claude/gsr-collector)
#   3. makes a Python virtualenv with the two dependencies
#   4. walks you through `rclone config` once if there is no "gdrive" remote
#   5. runs the full harvest into $GSR_DIR/GSR_Archive
#   6. copies the archive to Drive:/GSR_Archive (copy, never delete)
#
# Optional: export COURTLISTENER_TOKEN=... first to include NH court opinions.
set -euo pipefail

GSR_DIR="${GSR_DIR:-$HOME/Documents/GSR}"
REPO="https://github.com/dexterdow33/jqueryWeekly.git"
BRANCH="claude/gsr-collector"
CODE="$GSR_DIR/jqueryWeekly"
VENV="$GSR_DIR/.venv"
ARCHIVE="$GSR_DIR/GSR_Archive"
REMOTE="gdrive:GSR_Archive"

say() { printf '\n== %s\n' "$*"; }

command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required (xcode-select --install)" >&2; exit 1; }
command -v git >/dev/null || { echo "git is required (xcode-select --install)" >&2; exit 1; }

say "rclone"
command -v rclone >/dev/null || brew install rclone
rclone version | head -1

say "collector code in $CODE"
mkdir -p "$GSR_DIR"
if [ -d "$CODE/.git" ]; then
  git -C "$CODE" fetch -q origin "$BRANCH"
  git -C "$CODE" checkout -q "$BRANCH"
  git -C "$CODE" merge -q --ff-only "origin/$BRANCH"
else
  git clone -q --branch "$BRANCH" --single-branch "$REPO" "$CODE"
fi
git -C "$CODE" log --oneline -1

say "python environment"
[ -x "$VENV/bin/python" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$CODE/gsr-collector/requirements.txt"

if ! rclone listremotes | grep -qx 'gdrive:'; then
  say "Google Drive login (one time)"
  cat <<'EOT'
rclone will ask some questions. Answer:
  n            (new remote)
  name>        gdrive
  Storage>     drive
  client_id / client_secret: press Enter (blank)
  scope>       1   (full "drive" access: needed so rclone can add to the
                    GSR_Archive folder that already exists in your Drive)
  service_account_file: Enter;  advanced config: n;  auto config: y
  A browser opens: sign in as granitestatereport@gmail.com and allow.
  Shared drive: n;  then y to keep, q to quit.
EOT
  rclone config
  rclone listremotes | grep -qx 'gdrive:' || { echo "no gdrive remote was saved" >&2; exit 1; }
fi

say "harvest into $ARCHIVE"
mkdir -p "$ARCHIVE"
# pull the dedupe index down first so files already in Drive are not fetched again
rclone copy "$REMOTE/_index" "$ARCHIVE/_index" --exclude "staging/**" 2>/dev/null || true
set +e
( cd "$CODE/gsr-collector" && "$VENV/bin/python" -m gsr_collector --archive "$ARCHIVE" )
status=$?
set -e
[ $status -eq 2 ] && { echo "every source failed; check your network" >&2; exit 2; }

say "sync to $REMOTE"
rclone copy "$ARCHIVE" "$REMOTE" \
  --exclude "_index/staging/**" --exclude "*.part" --checksum --transfers 4 --progress

say "done"
ls -t "$ARCHIVE"/_index/runs/*_report.md | head -1

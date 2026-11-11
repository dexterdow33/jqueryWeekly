#!/usr/bin/env bash
# Push the local GSR archive to Google Drive with rclone (free).
#
# One-time setup on your computer:
#   1. Install rclone: https://rclone.org/downloads/
#   2. rclone config  ->  n (new remote)  ->  name: gdrive  ->  storage: drive
#      scope: drive.file  (rclone can only see files it created; safest)
#      sign in as granitestatereport@gmail.com when the browser opens.
#
# Usage:  scripts/sync_to_drive.sh [local_archive] [remote:folder]
set -euo pipefail

LOCAL="${1:-$HOME/GSR_Archive}"
REMOTE="${2:-gdrive:GSR_Archive}"

command -v rclone >/dev/null || { echo "rclone is not installed: https://rclone.org/downloads/" >&2; exit 1; }
[ -d "$LOCAL" ] || { echo "no archive at $LOCAL; run the collector first" >&2; exit 1; }

# copy, never sync: files deleted locally are never deleted from Drive
rclone copy "$LOCAL" "$REMOTE" \
  --exclude "_index/staging/**" --exclude "*.part" \
  --transfers 4 --checksum --progress
echo "archive pushed to $REMOTE"

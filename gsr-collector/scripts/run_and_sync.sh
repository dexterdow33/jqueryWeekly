#!/usr/bin/env bash
# One command: harvest, then push to Drive. Put this in cron or Task Scheduler.
#   crontab -e   ->   47 5 * * 1  /path/to/gsr-collector/scripts/run_and_sync.sh >> ~/gsr_collector.log 2>&1
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHIVE="${GSR_ARCHIVE:-$HOME/GSR_Archive}"
python3 -m gsr_collector --archive "$ARCHIVE" "$@"
scripts/sync_to_drive.sh "$ARCHIVE"

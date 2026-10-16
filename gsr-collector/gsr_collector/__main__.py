"""Command line:

  python -m gsr_collector                 # full run with config.yaml
  python -m gsr_collector --dry-run       # find and score only, download nothing
  python -m gsr_collector --only federal_register courtlistener
  python -m gsr_collector --config my.yaml --archive ~/Somewhere
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import yaml

from .pipeline import run


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="gsr_collector", description="Harvest documents into the GSR archive.")
    ap.add_argument("--config", default=str(Path(__file__).resolve().parent.parent / "config.yaml"))
    ap.add_argument("--archive", help="override archive_root from the config")
    ap.add_argument("--only", nargs="+", metavar="SOURCE", help="run only these sources")
    ap.add_argument("--dry-run", action="store_true", help="find and score, download nothing")
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args(argv)

    logging.basicConfig(level=logging.DEBUG if a.verbose else logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s")
    cfg = yaml.safe_load(Path(a.config).read_text(encoding="utf-8"))
    if a.archive:
        cfg["archive_root"] = a.archive
    stats = run(cfg, only=a.only, dry_run=a.dry_run)
    print(f"\nsource errors {stats['source_errors']}, found {stats['found']}, kept {stats['kept']}, new {stats['new']}, "
          f"duplicates {stats['duplicate']}, already archived {stats['already_had']}, "
          f"skipped {stats['skipped']}, failed {stats['failed']}, "
          f"{stats['bytes'] / 1e6:.1f} MB")
    print(f"report: {stats['report']}")
    if stats["source_errors"] and not stats["found"]:
        print("every query failed: check network access and the VERIFY sources in config.yaml")
        return 2
    return 1 if stats["failed"] and not stats["new"] else 0


if __name__ == "__main__":
    sys.exit(main())

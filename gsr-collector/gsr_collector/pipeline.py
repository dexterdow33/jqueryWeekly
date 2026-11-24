"""find -> score -> filter -> download -> file -> report."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from pathlib import Path

from .archive import Archive, guess_ext
from .http import PoliteSession, RobotsDisallowed, TooLarge
from .scoring import Scorer
from .sources import REGISTRY

log = logging.getLogger(__name__)


class _ErrorCounter(logging.Handler):
    """Counts errors the connectors log, so a run where every source is down
    is not reported as a clean run."""
    def __init__(self):
        super().__init__(logging.ERROR)
        self.count = 0

    def emit(self, record):
        self.count += 1


def build_session(cfg: dict) -> PoliteSession:
    h = cfg.get("http", {})
    return PoliteSession(
        user_agent=h.get("user_agent", "GSR-Collector/1.0"),
        delay_seconds=h.get("delay_seconds", 1.0),
        timeout=h.get("timeout_seconds", 60),
        max_retries=h.get("max_retries", 3),
        obey_robots=h.get("obey_robots", True),
    )


def run(cfg: dict, only: list[str] | None = None, dry_run: bool = False,
        session: PoliteSession | None = None) -> dict:
    session = session or build_session(cfg)
    archive = Archive(Path(cfg["archive_root"]))
    scorer = Scorer(cfg["scoring"])
    lim = cfg.get("limits", {})
    max_files = lim.get("max_downloads_per_run", 200)
    max_file = int(lim.get("max_file_mb", 500) * 1024 * 1024)
    max_run = int(lim.get("max_run_gb", 10) * 1024 ** 3)
    allowed = {e.lower() for e in lim.get("allowed_extensions", [])}

    errors = _ErrorCounter()
    src_log = logging.getLogger("gsr_collector.sources")
    src_log.addHandler(errors)

    stats = {"source_errors": 0, "found": 0, "kept": 0, "new": 0, "duplicate": 0, "already_had": 0,
             "skipped": 0, "failed": 0, "bytes": 0}
    rows: list[dict] = []
    started = datetime.now(timezone.utc)

    # 1. find and score everything first, so the best files download first
    candidates = []
    for name, scfg in cfg.get("sources", {}).items():
        if only and name not in only:
            continue
        if not scfg.get("enabled", True):
            continue
        mod = REGISTRY.get(scfg.get("type", name))
        if not mod:
            log.error("unknown source type for %s", name)
            continue
        log.info("searching %s", name)
        try:
            for c in mod.find(session, scfg):
                stats["found"] += 1
                scorer.score(c)
                # sources that are NH by construction (NH courts, NH .gov sites)
                c.score += scfg.get("score_bonus", 0)
                if c.beat == "Unsorted" and scfg.get("default_beat"):
                    c.beat = scfg["default_beat"]
                # score_cap: keep a source's long, keyword-heavy titles from
                # outranking primary documents (used for Internet Archive)
                if "score_cap" in scfg:
                    c.score = min(c.score, scfg["score_cap"])
                # require_nh: drop national material that never mentions NH
                if scfg.get("require_nh") and "NH" not in c.matched:
                    continue
                if scorer.keep(c):
                    candidates.append(c)
        except Exception as e:
            log.error("source %s crashed: %s", name, e)
            errors.count += 1
    src_log.removeHandler(errors)
    stats["source_errors"] = errors.count
    candidates.sort(key=lambda c: c.score, reverse=True)
    stats["kept"] = len(candidates)

    # 2. download in score order until a limit is hit
    seen = set()
    for c in candidates:
        if c.url in seen:
            continue
        seen.add(c.url)
        row = {"score": c.score, "beat": c.beat, "title": c.title, "url": c.url,
               "source": c.source, "status": ""}
        rows.append(row)
        if archive.has_url(c.url):
            row["status"] = "already in archive"
            stats["already_had"] += 1
            continue
        ext = guess_ext(c.url) if c.file_type in ("", "bin") else c.file_type
        if allowed and ext not in allowed and guess_ext(c.url) not in allowed:
            row["status"] = f"skipped: .{ext} not allowed"
            stats["skipped"] += 1
            continue
        if dry_run:
            row["status"] = "would download"
            continue
        if stats["new"] >= max_files or stats["bytes"] >= max_run:
            row["status"] = "skipped: run limit reached"
            stats["skipped"] += 1
            continue
        staged = archive.staging_path()
        try:
            sha, size, ctype = session.download(c.url, staged, max_file)
            if ctype.startswith("text/html") and c.file_type not in ("html", "htm"):
                staged.unlink(missing_ok=True)
                row["status"] = "skipped: got a web page, not a document"
                stats["skipped"] += 1
                continue
            status, path = archive.commit(c, staged, sha, size, ctype)
            stats[status] += 1
            stats["bytes"] += size if status == "new" else 0
            row["status"] = f"{status}: {path.relative_to(archive.root)}"
        except TooLarge as e:
            row["status"] = f"skipped: too large ({e})"
            stats["skipped"] += 1
        except RobotsDisallowed:
            row["status"] = "skipped: robots.txt disallows"
            stats["skipped"] += 1
        except Exception as e:
            row["status"] = f"failed: {e}"
            stats["failed"] += 1
        finally:
            staged.unlink(missing_ok=True)

    report = write_report(archive, started, stats, rows, dry_run)
    stats["report"] = str(report)
    return stats


def write_report(archive: Archive, started: datetime, stats: dict,
                 rows: list[dict], dry_run: bool) -> Path:
    path = archive.index_dir / "runs" / f"{started:%Y-%m-%dT%H%M%SZ}_{'dryrun' if dry_run else 'run'}_report.md"
    lines = [
        f"# GSR Collector {'dry run' if dry_run else 'run'}, {started:%Y-%m-%d %H:%M} UTC",
        "",
        "| source errors | found | kept (scored high enough) | new files | duplicates | already archived | skipped | failed | MB downloaded |",
        "|---|---|---|---|---|---|---|---|---|",
        f"| {stats['source_errors']} | {stats['found']} | {stats['kept']} | {stats['new']} | {stats['duplicate']} | {stats['already_had']} "
        f"| {stats['skipped']} | {stats['failed']} | {stats['bytes'] / 1e6:.1f} |",
        "",
        "| score | beat | title | source | status |",
        "|---|---|---|---|---|",
    ]
    for r in rows:
        title = r["title"].replace("|", "/")[:100]
        lines.append(f"| {r['score']:.0f} | {r['beat']} | [{title}]({r['url']}) | {r['source']} | {r['status']} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path

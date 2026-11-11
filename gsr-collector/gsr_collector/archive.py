"""The GSR archive on disk.

Layout:
  <root>/<Beat>/<YYYY-MM>/<YYYY-MM-DD>_<source>_<slug>_<hash8>.<ext>
  <root>/<Beat>/<YYYY-MM>/<same name>.source.json   provenance sidecar
  <root>/_index/archive.sqlite                       dedupe index
  <root>/_index/manifest.csv                         one row per kept file
  <root>/_index/runs/<timestamp>_report.md           what each run did

Every file keeps its source URL, retrieval time and SHA-256, so anything you
cite from the archive can be traced back to where and when it came from."""

from __future__ import annotations

import csv
import json
import mimetypes
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit

from .models import Candidate

CONTENT_TYPE_EXT = {
    "application/pdf": "pdf",
    "text/csv": "csv",
    "application/json": "json",
    "application/zip": "zip",
    "application/vnd.ms-excel": "xls",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx",
    "application/msword": "doc",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
    "text/plain": "txt",
    "text/html": "html",
    "application/xml": "xml",
    "text/xml": "xml",
}


def slugify(text: str, max_len: int = 60) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-")
    return (s[:max_len].rstrip("-") or "untitled")


def guess_ext(url: str, content_type: str = "") -> str:
    name = unquote(urlsplit(url).path.rsplit("/", 1)[-1])
    if "." in name:
        ext = name.rsplit(".", 1)[1].lower()
        if 1 <= len(ext) <= 5 and ext.isalnum():
            return ext
    ct = content_type.split(";")[0].strip().lower()
    if ct in CONTENT_TYPE_EXT:
        return CONTENT_TYPE_EXT[ct]
    ext = mimetypes.guess_extension(ct) if ct else None
    return ext.lstrip(".") if ext else "bin"


class Archive:
    MANIFEST_FIELDS = ["retrieved_at", "beat", "score", "source", "title",
                       "publisher", "published", "path", "bytes", "sha256",
                       "url", "landing_page"]

    def __init__(self, root: Path):
        self.root = Path(root).expanduser().resolve()
        self.index_dir = self.root / "_index"
        self.index_dir.mkdir(parents=True, exist_ok=True)
        (self.index_dir / "runs").mkdir(exist_ok=True)
        self.db = sqlite3.connect(self.index_dir / "archive.sqlite")
        self.db.execute("""CREATE TABLE IF NOT EXISTS files (
            url TEXT PRIMARY KEY, sha256 TEXT, path TEXT, retrieved_at TEXT)""")
        self.db.execute("CREATE INDEX IF NOT EXISTS ix_sha ON files(sha256)")
        self.db.commit()

    def has_url(self, url: str) -> bool:
        return self.db.execute("SELECT 1 FROM files WHERE url=?", (url,)).fetchone() is not None

    def path_for_sha(self, sha: str) -> str | None:
        row = self.db.execute("SELECT path FROM files WHERE sha256=?", (sha,)).fetchone()
        return row[0] if row else None

    def staging_path(self) -> Path:
        d = self.index_dir / "staging"
        d.mkdir(exist_ok=True)
        return d / f"dl_{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f')}"

    def final_path(self, c: Candidate, ext: str, sha: str, now: datetime) -> Path:
        beat_dir = slugify(c.beat, 40).replace("-", "_")
        folder = self.root / beat_dir / now.strftime("%Y-%m")
        folder.mkdir(parents=True, exist_ok=True)
        name = f"{now:%Y-%m-%d}_{slugify(c.source, 30)}_{slugify(c.title)}_{sha[:8]}.{ext}"
        p = (folder / name).resolve()
        if self.root not in p.parents:          # never write outside the archive
            raise ValueError(f"refusing path outside archive: {p}")
        return p

    def commit(self, c: Candidate, staged: Path, sha: str, size: int,
               content_type: str) -> tuple[str, Path]:
        """Move a staged download into place. Returns (status, path) where
        status is 'new' or 'duplicate' (same bytes already archived)."""
        now = datetime.now(timezone.utc)
        existing = self.path_for_sha(sha)
        if existing:
            staged.unlink(missing_ok=True)
            self._record(c.url, sha, existing, now)
            # keep every place the same bytes were published, e.g. the
            # official Federal Register copy of a PDF first found on a mirror
            side = self.root / (existing + ".source.json")
            if side.exists():
                meta = json.loads(side.read_text(encoding="utf-8"))
                meta.setdefault("also_found_at", []).append(
                    {"url": c.url, "source": c.source, "landing_page": c.landing_page,
                     "publisher": c.publisher, "retrieved_at": now.isoformat()})
                side.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
            return "duplicate", self.root / existing
        ext = guess_ext(c.url, content_type)
        dest = self.final_path(c, ext, sha, now)
        staged.replace(dest)
        rel = str(dest.relative_to(self.root))
        meta = {
            "title": c.title, "url": c.url, "landing_page": c.landing_page,
            "source": c.source, "publisher": c.publisher, "published": c.published,
            "description": c.description[:4000], "beat": c.beat, "score": c.score,
            "matched_terms": c.matched, "retrieved_at": now.isoformat(),
            "sha256": sha, "bytes": size, "content_type": content_type,
            "extra": c.extra,
        }
        dest.with_name(dest.name + ".source.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
        self._record(c.url, sha, rel, now)
        self._manifest_row({**meta, "path": rel})
        return "new", dest

    def _record(self, url, sha, rel, now):
        self.db.execute("INSERT OR REPLACE INTO files VALUES (?,?,?,?)",
                        (url, sha, rel, now.isoformat()))
        self.db.commit()

    def _manifest_row(self, meta: dict) -> None:
        path = self.index_dir / "manifest.csv"
        new = not path.exists()
        with path.open("a", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=self.MANIFEST_FIELDS, extrasaction="ignore")
            if new:
                w.writeheader()
            w.writerow(meta)

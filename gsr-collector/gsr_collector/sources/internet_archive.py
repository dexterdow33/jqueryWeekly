"""Internet Archive: advancedsearch.php to find items, /metadata/<id> to list
their files. Only original uploads are taken, not derived OCR or thumbnails."""

from __future__ import annotations

import logging
from urllib.parse import quote

from ..models import Candidate

log = logging.getLogger(__name__)

SEARCH = "https://archive.org/advancedsearch.php"
BASE = "https://archive.org"


def find(session, cfg):
    exts = {e.lower() for e in cfg.get("extensions", ["pdf", "csv", "xlsx", "zip"])}
    base = cfg.get("base_url", BASE).rstrip("/")
    for q in cfg.get("queries", []):
        params = {"q": q, "fl[]": ["identifier", "title", "description", "date", "creator"],
                  "rows": cfg.get("rows", 20), "sort[]": "publicdate desc", "output": "json"}
        try:
            docs = session.get_json(cfg.get("search_url", SEARCH), params=params)["response"]["docs"]
        except Exception as e:
            log.error("internet_archive %r failed: %s", q, e)
            continue
        for d in docs:
            ident = d["identifier"]
            try:
                meta = session.get_json(f"{base}/metadata/{quote(ident)}")
            except Exception as e:
                log.error("internet_archive metadata %s failed: %s", ident, e)
                continue
            desc = d.get("description") or ""
            if isinstance(desc, list):
                desc = " ".join(desc)
            for f in meta.get("files", []):
                name = f.get("name", "")
                ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
                if f.get("source") != "original" or ext not in exts:
                    continue
                yield Candidate(
                    url=f"{base}/download/{quote(ident)}/{quote(name)}",
                    title=f"{d.get('title', ident)} - {name}",
                    description=desc,
                    publisher=d.get("creator", "") if isinstance(d.get("creator"), str) else ", ".join(d.get("creator") or []),
                    published=(d.get("date") or "")[:10],
                    landing_page=f"{base}/details/{ident}",
                    file_type=ext,
                    source="internet_archive",
                    extra={"identifier": ident, "query": q},
                )

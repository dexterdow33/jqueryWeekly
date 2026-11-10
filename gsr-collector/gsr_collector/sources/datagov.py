"""catalog.data.gov search (the catalog that replaced data.gov's CKAN API).

GET /search?q=...&per_page=N returns {"results": [...], "after": cursor}.
Each result carries a DCAT record; its dcat.distribution[] entries with a
downloadURL are the files. Pass the `after` cursor back to get the next page.
Checked against the live API on 2026-11-10."""

from __future__ import annotations

import html
import logging
import re

from ..archive import CONTENT_TYPE_EXT, guess_ext
from ..models import Candidate

log = logging.getLogger(__name__)

BASE = "https://catalog.data.gov"


def _plain(text: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", " ", text or "")).strip()


def find(session, cfg):
    base = cfg.get("base_url", BASE).rstrip("/")
    per_page = cfg.get("rows", 50)
    pages = cfg.get("pages", 1)
    for q in cfg.get("queries", []):
        after = None
        for _ in range(pages):
            params = {"q": q, "per_page": per_page}
            if after:
                params["after"] = after
            try:
                data = session.get_json(f"{base}/search", params=params)
            except Exception as e:
                log.error("datagov %r failed: %s", q, e)
                break
            for r in data.get("results", []):
                dcat = r.get("dcat") or {}
                if not isinstance(dcat, dict):
                    continue
                desc = _plain(r.get("description") or dcat.get("description", ""))
                for dist in dcat.get("distribution") or []:   # null on some records
                    if not isinstance(dist, dict):
                        continue
                    url = dist.get("downloadURL")
                    if not url:
                        continue        # accessURL is a web page, not a file
                    ext = CONTENT_TYPE_EXT.get((dist.get("mediaType") or "").lower()) \
                        or (dist.get("format") or "").lower() or guess_ext(url)
                    yield Candidate(
                        url=url,
                        title=f"{r.get('title', '')} - {dist.get('title') or ext}".strip(" -"),
                        description=desc,
                        publisher=r.get("publisher") or (r.get("organization") or {}).get("name", ""),
                        published=(dcat.get("modified") or dist.get("modified") or "")[:10],
                        landing_page=f"{base}/dataset/{r.get('slug', '')}",
                        file_type=ext,
                        source="data_gov",
                        extra={"identifier": r.get("identifier"), "query": q},
                    )
            after = data.get("after")
            if not after:
                break

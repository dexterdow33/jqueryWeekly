"""CourtListener (Free Law Project) opinion search, REST API v4.
An API token is optional but raises rate limits: set COURTLISTENER_TOKEN.
Opinion files are served from storage.courtlistener.com via local_path."""

from __future__ import annotations

import logging
import os

from ..archive import guess_ext
from ..models import Candidate

log = logging.getLogger(__name__)

API = "https://www.courtlistener.com/api/rest/v4/search/"
STORAGE = "https://storage.courtlistener.com/"
SITE = "https://www.courtlistener.com"


def find(session, cfg):
    storage = cfg.get("storage_url", STORAGE)
    site = cfg.get("site_url", SITE)
    headers = {}
    token = os.environ.get("COURTLISTENER_TOKEN")
    if token:
        headers["Authorization"] = f"Token {token}"
    for q in cfg.get("queries", []):
        params = {"q": q, "type": "o", "order_by": "dateFiled desc"}
        if cfg.get("courts"):
            params["court"] = " ".join(cfg["courts"])
        try:
            data = session.get_json(cfg.get("api", API), params=params, headers=headers)
        except Exception as e:
            log.error("courtlistener %r failed: %s", q, e)
            continue
        for hit in data.get("results", [])[: cfg.get("rows", 20)]:
            for op in hit.get("opinions", []):
                path = op.get("local_path")
                url = storage + path if path else op.get("download_url")
                if not url:
                    continue
                yield Candidate(
                    url=url,
                    title=hit.get("caseName", "") + (f" ({hit.get('dateFiled')})" if hit.get("dateFiled") else ""),
                    description=op.get("snippet") or "",
                    publisher=hit.get("court", ""),
                    published=hit.get("dateFiled", ""),
                    landing_page=site + hit.get("absolute_url", ""),
                    file_type=guess_ext(url),
                    source="courtlistener",
                    extra={"cluster_id": hit.get("cluster_id"), "docket": hit.get("docketNumber"),
                           "query": q},
                )

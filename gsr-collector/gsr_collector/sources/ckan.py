"""Any CKAN open-data portal (catalog.data.gov runs CKAN). Uses the standard
CKAN Action API: /api/3/action/package_search. Each dataset can carry many
resource files; each resource becomes one candidate."""

from __future__ import annotations

import logging

from ..models import Candidate

log = logging.getLogger(__name__)


def find(session, cfg):
    for portal in cfg.get("portals", []):
        base = portal["base_url"].rstrip("/")
        formats = {f.lower() for f in portal.get("formats", [])}
        for q in portal.get("queries", []):
            url = f"{base}/api/3/action/package_search"
            params = {"q": q, "rows": portal.get("rows", 25),
                      "sort": "metadata_modified desc"}
            try:
                data = session.get_json(url, params=params)
            except Exception as e:
                log.error("ckan %s %r failed: %s", base, q, e)
                continue
            for ds in data.get("result", {}).get("results", []):
                org = (ds.get("organization") or {}).get("title", "")
                landing = f"{base}/dataset/{ds.get('name', '')}"
                for res in ds.get("resources", []):
                    fmt = (res.get("format") or "").lower()
                    if formats and fmt not in formats:
                        continue
                    if not res.get("url"):
                        continue
                    yield Candidate(
                        url=res["url"],
                        title=f"{ds.get('title', '')} - {res.get('name') or fmt}".strip(" -"),
                        description=(ds.get("notes") or "") + "\n" + (res.get("description") or ""),
                        publisher=org,
                        published=(ds.get("metadata_modified") or "")[:10],
                        landing_page=landing,
                        file_type=fmt,
                        source=portal.get("name", "ckan"),
                        extra={"dataset_id": ds.get("id"), "query": q},
                    )

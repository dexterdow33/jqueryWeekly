"""Federal Register public API (no key): /api/v1/documents.json.
Rules, proposed rules and notices; each document's official PDF is the file."""

from __future__ import annotations

import logging

from ..models import Candidate

log = logging.getLogger(__name__)

API = "https://www.federalregister.gov/api/v1/documents.json"


def find(session, cfg):
    for q in cfg.get("queries", []):
        params = {"conditions[term]": q, "per_page": cfg.get("rows", 25),
                  "order": "newest"}
        try:
            data = session.get_json(cfg.get("api", API), params=params)
        except Exception as e:
            log.error("federal_register %r failed: %s", q, e)
            continue
        for d in data.get("results", []):
            if not d.get("pdf_url"):
                continue
            agencies = ", ".join(a.get("name", "") for a in d.get("agencies", []) if a)
            yield Candidate(
                url=d["pdf_url"],
                title=d.get("title", ""),
                description=d.get("abstract") or "",
                publisher=agencies,
                published=d.get("publication_date", ""),
                landing_page=d.get("html_url", ""),
                file_type="pdf",
                source="federal_register",
                extra={"document_number": d.get("document_number"),
                       "type": d.get("type"), "query": q},
            )

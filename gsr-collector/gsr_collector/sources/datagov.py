"""catalog.data.gov search (the catalog that replaced data.gov's CKAN API).

GET /search?q=...&per_page=N returns {"results": [...], "after": cursor}.
Each result carries a DCAT record; its dcat.distribution[] entries with a
downloadURL are the files. Pass the `after` cursor back to get the next page.
Checked against the live API on 2026-11-10."""

from __future__ import annotations

import html
import logging
import re

from urllib.parse import urldefrag, urljoin, urlsplit

from ..archive import CONTENT_TYPE_EXT, guess_ext
from ..models import Candidate
from .crawler import DEFAULT_EXTS, _Links, _ext

log = logging.getLogger(__name__)

BASE = "https://catalog.data.gov"


def _plain(text: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", " ", text or "")).strip()


PAGE_EXTS = {"html", "htm", "aspx", "php", ""}


def _follow_page(session, page_url, max_docs, exts):
    """Open a landing page data.gov lists in place of a file and return the
    document links on it, same host only: [(url, link_text, ext)].
    SAMHSA's NH reports, for one, are listed this way."""
    final, html_text = session.get_text(page_url)
    parser = _Links()
    try:
        parser.feed(html_text)
    except Exception as e:  # malformed HTML: keep whatever was parsed
        log.debug("parse error %s: %s", page_url, e)
    host = urlsplit(final).netloc
    found, seen = [], set()
    for href, text in parser.links:
        url, _ = urldefrag(urljoin(final, href))
        if urlsplit(url).netloc != host or url in seen:
            continue
        ext = _ext(url)
        if ext in exts:
            seen.add(url)
            found.append((url, text, ext))
            if len(found) >= max_docs:
                break
    return found


def find(session, cfg):
    base = cfg.get("base_url", BASE).rstrip("/")
    per_page = cfg.get("rows", 50)
    follow = cfg.get("follow_pages", False)
    max_docs = cfg.get("max_docs_per_page", 5)
    exts = set(cfg.get("follow_extensions", DEFAULT_EXTS))
    # only open pages on these hosts; most page-type entries are national
    # tools (IRS, USDA) that require_nh would drop anyway
    follow_hosts = set(cfg.get("follow_hosts", []))
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
                    if follow and ext in PAGE_EXTS and \
                            (not follow_hosts or urlsplit(url).netloc in follow_hosts):
                        # a web page, not a file: open it and take its documents
                        try:
                            docs = _follow_page(session, url, max_docs, exts)
                        except Exception as e:
                            log.warning("datagov could not follow %s: %s", url, e)
                            docs = []
                        for doc_url, text, doc_ext in docs:
                            yield Candidate(
                                url=doc_url,
                                title=f"{r.get('title', '')} - {text or doc_url.rsplit('/', 1)[-1]}",
                                description=desc,
                                publisher=r.get("publisher") or (r.get("organization") or {}).get("name", ""),
                                published=(dcat.get("modified") or dist.get("modified") or "")[:10],
                                landing_page=url,
                                file_type=doc_ext,
                                source="data_gov",
                                extra={"identifier": r.get("identifier"), "query": q,
                                       "followed_from": url,
                                       "dataset_page": f"{base}/dataset/{r.get('slug', '')}"},
                            )
                        if docs:
                            continue
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

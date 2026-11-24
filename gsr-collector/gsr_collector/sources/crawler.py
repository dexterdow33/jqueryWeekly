"""Document crawler for sites with no API (state agencies, towns, courts).

Starts at each seed page, follows links that stay on the seed's own domain
up to `depth` hops, and emits every link that ends in a document extension.
Obeys robots.txt and the per-host delay through PoliteSession."""

from __future__ import annotations

import logging
from collections import deque
from html.parser import HTMLParser
from urllib.parse import parse_qs, urldefrag, urljoin, urlsplit

from ..models import Candidate

log = logging.getLogger(__name__)

DEFAULT_EXTS = ["pdf", "csv", "xls", "xlsx", "doc", "docx", "zip", "json", "xml"]


class _Links(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links: list[tuple[str, str]] = []
        self.title = ""
        self._href = None
        self._text: list[str] = []
        self._in_title = False

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self._href = dict(attrs).get("href")
            self._text = []
        elif tag == "title":
            self._in_title = True

    def handle_endtag(self, tag):
        if tag == "a" and self._href:
            self.links.append((self._href, " ".join("".join(self._text).split())))
            self._href = None
        elif tag == "title":
            self._in_title = False

    def handle_data(self, data):
        if self._href is not None:
            self._text.append(data)
        if self._in_title:
            self.title += data


def _ext(url: str) -> str:
    last = urlsplit(url).path.rsplit("/", 1)[-1]
    return last.rsplit(".", 1)[-1].lower() if "." in last else ""


def _query_doc_ext(url: str, exts: set[str]) -> str:
    """Documents served through a viewer page, e.g. the NH House Record at
    viewer.aspx?fileName=Calendars\\2026\\No12+March+20+2026.PDF"""
    for values in parse_qs(urlsplit(url).query).values():
        for v in values:
            ext = v.rsplit(".", 1)[-1].lower() if "." in v else ""
            if ext in exts:
                return ext
    return ""


def find(session, cfg):
    exts = set(cfg.get("extensions", DEFAULT_EXTS))
    max_pages = cfg.get("max_pages_per_seed", 200)
    for seed in cfg.get("seeds", []):
        start = seed["url"]
        domain = urlsplit(start).netloc
        prefix = seed.get("path_prefix", "")
        depth_limit = seed.get("depth", 1)
        seen_pages, seen_docs = {start}, set()
        queue = deque([(start, 0)])
        pages = 0
        while queue and pages < max_pages:
            page, depth = queue.popleft()
            try:
                final, html = session.get_text(page)
            except Exception as e:
                if page == start:   # the whole seed is dead: count it as a source error
                    log.error("crawler seed %s unreachable: %s", start, e)
                else:
                    log.warning("crawler skip %s: %s", page, e)
                continue
            pages += 1
            parser = _Links()
            try:
                parser.feed(html)
            except Exception as e:  # malformed HTML: keep whatever was parsed
                log.debug("parse error %s: %s", page, e)
            page_title = " ".join(parser.title.split())
            for href, text in parser.links:
                url, _ = urldefrag(urljoin(final, href))
                parts = urlsplit(url)
                if parts.scheme not in ("http", "https"):
                    continue
                ext = _ext(url)
                if ext not in exts:
                    ext = _query_doc_ext(url, exts) or ext
                if ext in exts:
                    if url in seen_docs:
                        continue
                    seen_docs.add(url)
                    name = parts.path.rsplit("/", 1)[-1] if _ext(url) in exts else url.rsplit("\\", 1)[-1]
                    yield Candidate(
                        url=url,
                        title=text or name,
                        description=f"Linked from: {page_title}",
                        publisher=seed.get("publisher", domain),
                        landing_page=final,
                        file_type=ext,
                        source=seed.get("name", "crawler"),
                    )
                elif (parts.netloc == domain and parts.path.startswith(prefix)
                      and depth < depth_limit and url not in seen_pages
                      and ext in ("", "html", "htm", "aspx", "php")):
                    seen_pages.add(url)
                    queue.append((url, depth + 1))

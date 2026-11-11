"""Polite HTTP client: identifies itself, obeys robots.txt, rate-limits per host,
retries transient failures, and streams downloads with a hard size cap."""

from __future__ import annotations

import hashlib
import logging
import time
import urllib.robotparser
from pathlib import Path
from urllib.parse import urlsplit

import requests

log = logging.getLogger(__name__)

RETRY_STATUS = {429, 500, 502, 503, 504}


class TooLarge(Exception):
    pass


class RobotsDisallowed(Exception):
    pass


class PoliteSession:
    def __init__(self, user_agent: str, delay_seconds: float = 1.0,
                 timeout: float = 60, max_retries: int = 3,
                 obey_robots: bool = True):
        self.s = requests.Session()
        self.s.headers["User-Agent"] = user_agent
        self.user_agent = user_agent
        self.delay = delay_seconds
        self.timeout = timeout
        self.max_retries = max_retries
        self.obey_robots = obey_robots
        self._last_hit: dict[str, float] = {}
        self._robots: dict[str, urllib.robotparser.RobotFileParser | None] = {}

    # -- etiquette -------------------------------------------------------
    def _host(self, url: str) -> str:
        p = urlsplit(url)
        return f"{p.scheme}://{p.netloc}"

    def _throttle(self, url: str) -> None:
        host = self._host(url)
        wait = self._last_hit.get(host, 0) + self.delay - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        self._last_hit[host] = time.monotonic()

    def allowed(self, url: str) -> bool:
        if not self.obey_robots:
            return True
        host = self._host(url)
        if host not in self._robots:
            rp = urllib.robotparser.RobotFileParser()
            try:
                r = self.s.get(host + "/robots.txt", timeout=self.timeout)
                if r.status_code >= 400:
                    rp = None  # no robots.txt: everything allowed
                else:
                    rp.parse(r.text.splitlines())
            except requests.RequestException:
                rp = None
            self._robots[host] = rp
        rp = self._robots[host]
        return rp is None or rp.can_fetch(self.user_agent, url)

    # -- requests --------------------------------------------------------
    def request(self, method: str, url: str, **kw) -> requests.Response:
        if not self.allowed(url):
            raise RobotsDisallowed(url)
        kw.setdefault("timeout", self.timeout)
        for attempt in range(self.max_retries + 1):
            self._throttle(url)
            try:
                r = self.s.request(method, url, **kw)
            except requests.RequestException as e:
                if attempt == self.max_retries:
                    raise
                log.warning("retry %s after %s", url, e)
            else:
                if r.status_code not in RETRY_STATUS or attempt == self.max_retries:
                    r.raise_for_status()
                    return r
                log.warning("retry %s after HTTP %s", url, r.status_code)
            time.sleep(2 ** attempt)
        raise RuntimeError("unreachable")

    def get_json(self, url: str, **kw):
        return self.request("GET", url, **kw).json()

    def get_text(self, url: str, **kw) -> tuple[str, str]:
        """Returns (final_url, text)."""
        r = self.request("GET", url, **kw)
        return r.url, r.text

    def download(self, url: str, dest: Path, max_bytes: int) -> tuple[str, int, str]:
        """Stream url to dest. Returns (sha256, size, content_type).
        Writes to a .part file first so a failed download never looks finished."""
        r = self.request("GET", url, stream=True)
        declared = int(r.headers.get("Content-Length") or 0)
        if declared > max_bytes:
            r.close()
            raise TooLarge(f"{url} declares {declared} bytes")
        part = dest.with_name(dest.name + ".part")
        h, size = hashlib.sha256(), 0
        try:
            with part.open("wb") as f:
                for chunk in r.iter_content(1 << 16):
                    size += len(chunk)
                    if size > max_bytes:
                        raise TooLarge(f"{url} exceeded {max_bytes} bytes")
                    h.update(chunk)
                    f.write(chunk)
            part.replace(dest)
        except BaseException:
            part.unlink(missing_ok=True)
            raise
        finally:
            r.close()
        return h.hexdigest(), size, r.headers.get("Content-Type", "")

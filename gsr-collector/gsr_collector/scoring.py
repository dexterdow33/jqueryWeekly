"""Decides what is worth keeping and which beat folder it belongs in.

Score = sum of beat keyword hits (title hits count triple)
      + NH bonus if the text mentions New Hampshire
      + file-type bonus (primary documents and data beat web pages).
Highest-scoring beat wins the folder. Below min_score, the file is skipped."""

from __future__ import annotations

import re

from .models import Candidate


def _pattern(term: str) -> re.Pattern:
    return re.compile(r"\b" + re.escape(term.lower()) + r"\b")


class Scorer:
    def __init__(self, cfg: dict):
        self.beats = {
            beat: [(t, _pattern(t)) for t in terms]
            for beat, terms in cfg["beats"].items()
        }
        self.nh_terms = [_pattern(t) for t in cfg.get("nh_terms", [])]
        self.nh_bonus = cfg.get("nh_bonus", 3)
        self.type_bonus = cfg.get("file_type_bonus", {})
        self.min_score = cfg.get("min_score", 4)

    def score(self, c: Candidate) -> Candidate:
        title = c.title.lower()
        body = c.text().lower()
        best, best_pts, total = "Unsorted", 0.0, 0.0
        matched: list[str] = []
        for beat, terms in self.beats.items():
            pts = 0.0
            for term, pat in terms:
                if pat.search(title):
                    pts += 3
                    matched.append(term)
                elif pat.search(body):
                    pts += 1
                    matched.append(term)
            total += pts
            if pts > best_pts:
                best, best_pts = beat, pts
        if any(p.search(body) for p in self.nh_terms):
            total += self.nh_bonus
            matched.append("NH")
        total += self.type_bonus.get(c.file_type, 0)
        c.score, c.beat, c.matched = total, best, sorted(set(matched))
        return c

    def keep(self, c: Candidate) -> bool:
        return c.score >= self.min_score and c.beat != "Unsorted"

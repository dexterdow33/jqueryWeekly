from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Candidate:
    """One downloadable file a source found. Nothing is downloaded yet."""
    url: str
    title: str
    source: str                      # connector name, e.g. "federal_register"
    description: str = ""
    publisher: str = ""
    published: str = ""              # ISO date if the source gives one
    landing_page: str = ""           # human-readable page about the file
    file_type: str = ""              # pdf, csv, xlsx ... (best guess)
    extra: dict = field(default_factory=dict)

    # filled in by scoring
    score: float = 0.0
    beat: str = "Unsorted"
    matched: list[str] = field(default_factory=list)

    def text(self) -> str:
        return f"{self.title}\n{self.description}\n{self.publisher}"

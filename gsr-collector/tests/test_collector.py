"""End-to-end tests against a local HTTP server that imitates each source.
These prove the pipeline works; they do not prove the live APIs still answer
the same way. Run a --dry-run against the real config for that."""

import csv
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from gsr_collector.archive import Archive, slugify
from gsr_collector.models import Candidate
from gsr_collector.pipeline import run
from gsr_collector.scoring import Scorer

PDF = b"%PDF-1.4 fake test document\n"


def make_routes(base):
    return {
        "/robots.txt": ("text/plain", b"User-agent: *\nDisallow: /private/\n"),
        # shape of catalog.data.gov/search as returned live on 2026-11-10
        "/search": ("application/json", json.dumps({"after": None, "sort": "relevance", "results": [
            {"title": "New Hampshire State Police Traffic Stops", "slug": "nh-police-stops",
             "description": "<p>Stop data released under RSA 91-A.</p>", "publisher": "NH DOS",
             "identifier": "ds1",
             "dcat": {"modified": "2026-09-01", "distribution": [
                 {"downloadURL": f"{base}/files/stops.csv", "mediaType": "text/csv", "title": "stops"},
                 {"accessURL": f"{base}/files/stops.html", "title": "web view"}]}},
            {"title": "New Hampshire record with no files", "slug": "x", "dcat": {"distribution": None}},
            # listed as a web page, the way SAMHSA's NH reports are
            {"title": "Behavioral Health Barometer: New Hampshire, Volume 6", "slug": "bhb-nh-6",
             "description": "Mental health and substance use in New Hampshire.", "publisher": "SAMHSA",
             "dcat": {"distribution": [
                 {"downloadURL": f"{base}/samhsa/report/bhb-nh-6", "mediaType": "text/html"}]}},
        ]}).encode()),
        "/fr/documents.json": ("application/json", json.dumps({"results": [{
            "title": "Privacy Act of 1974; System of Records (New Hampshire surveillance program)",
            "abstract": "Notice.", "pdf_url": f"{base}/files/fr.pdf", "html_url": f"{base}/fr/1",
            "publication_date": "2026-10-01", "agencies": [{"name": "DHS"}],
            "document_number": "2026-0001", "type": "Notice"}]}).encode()),
        "/cl/search/": ("application/json", json.dumps({"results": [{
            "caseName": "Doe v. Town of Exeter", "dateFiled": "2026-08-15", "court": "nh",
            "absolute_url": "/opinion/1/doe/", "cluster_id": 1, "docketNumber": "2025-0001",
            "opinions": [{"local_path": "files/op.pdf", "snippet": "right-to-know public records"}]}]}).encode()),
        "/ia/advancedsearch.php": ("application/json", json.dumps({"response": {"docs": [{
            "identifier": "nhaudit", "title": "New Hampshire State Audit Report", "date": "2001-01-01"}]}}).encode()),
        "/ia/metadata/nhaudit": ("application/json", json.dumps({"files": [
            {"name": "audit.pdf", "source": "original"},
            {"name": "audit_djvu.txt", "source": "derivative"}]}).encode()),
        "/ia/download/nhaudit/audit.pdf": ("application/pdf", PDF + b"audit"),
        "/site/index.html": ("text/html", f"""<html><title>NH DOJ Reports</title>
            <a href="/files/investigation.pdf">Attorney General investigation report, police misconduct</a>
            <a href="/site/sub.html">More reports</a>
            <a href="/private/secret.pdf">Secret audit report New Hampshire</a>
            <a href="/files/fake.pdf">Audit report that is really a login page</a>
            <a href="https://elsewhere.example/x.pdf">offsite audit</a>
            <a href="mailto:x@y">mail</a></html>""".encode()),
        "/site/sub.html": ("text/html", b"""<html><title>Archive</title>
            <a href="/files/fr_copy.pdf">Privacy surveillance audit copy</a>
            <a href="/files/huge.pdf">Huge audit report surveillance</a>
            <a href="/house/viewer.aspx?fileName=Calendars\\2026\\No12+March+20+2026.PDF">House Record: committee report on HB 1576</a></html>"""),
        "/house/viewer.aspx": ("application/pdf", PDF + b"house record"),
        "/samhsa/report/bhb-nh-6": ("text/html", b"""<html><title>Barometer</title>
            <a href="/data/files/NewHampshire-BH-Barometer_Volume6.pdf">Download the report</a>
            <a href="https://elsewhere.example/other.pdf">Someone else's PDF</a></html>"""),
        "/data/files/NewHampshire-BH-Barometer_Volume6.pdf": ("application/pdf", PDF + b"barometer"),
        "/files/stops.csv": ("text/csv", b"date,town\n2026-01-01,Concord\n"),
        "/files/stops.html": ("text/html", b"<html>web</html>"),
        "/files/fr.pdf": ("application/pdf", PDF + b"fr"),
        "/files/fr_copy.pdf": ("application/pdf", PDF + b"fr"),        # same bytes as fr.pdf
        "/files/op.pdf": ("application/pdf", PDF + b"opinion"),
        "/files/investigation.pdf": ("application/pdf", PDF + b"inv"),
        "/files/fake.pdf": ("text/html", b"<html>please log in</html>"),
        "/files/huge.pdf": ("application/pdf", PDF + b"x" * 300_000),
        "/private/secret.pdf": ("application/pdf", PDF + b"secret"),
    }


@pytest.fixture(scope="module")
def server():
    routes = {}

    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            path = self.path.split("?", 1)[0]
            if path not in routes:
                self.send_error(404)
                return
            ctype, body = routes[path]
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass

    srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
    base = f"http://127.0.0.1:{srv.server_port}"
    routes.update(make_routes(base))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield base
    srv.shutdown()


def config(base, root):
    cfg = __import__("yaml").safe_load((Path(__file__).parent.parent / "config.yaml").read_text())
    cfg["archive_root"] = str(root)
    cfg["http"]["delay_seconds"] = 0
    cfg["http"]["max_retries"] = 0
    cfg["limits"]["max_file_mb"] = 0.1
    s = cfg["sources"]
    s["datagov"].update(base_url=base, queries=["x"], pages=1,
                        follow_hosts=[base.split("//", 1)[1]])
    s["federal_register"].update(api=f"{base}/fr/documents.json", queries=["x"])
    s["courtlistener"].update(api=f"{base}/cl/search/", storage_url=f"{base}/",
                              site_url=base, queries=["x"])
    s["internet_archive"].update(search_url=f"{base}/ia/advancedsearch.php",
                                 base_url=f"{base}/ia", queries=["x"])
    s["crawler"]["seeds"] = [{"name": "nh_doj", "url": f"{base}/site/index.html",
                              "publisher": "NH DOJ", "depth": 1}]
    return cfg


def test_full_run_then_rerun(server, tmp_path):
    cfg = config(server, tmp_path)
    stats = run(cfg)
    root = tmp_path.resolve()
    files = sorted(p.relative_to(root).as_posix() for p in root.rglob("*")
                   if p.is_file() and not p.name.endswith(".source.json") and "_index" not in p.parts)

    # stops.csv, fr.pdf, op.pdf, audit.pdf, investigation.pdf, House Record via
    # viewer.aspx, Barometer PDF followed from its report page
    assert stats["new"] == 7, files
    assert stats["duplicate"] == 1                     # fr_copy.pdf has fr.pdf's bytes
    assert len(files) == 7
    barometer = [f for f in files if "Barometer" in f]
    assert len(barometer) == 1 and barometer[0].startswith("Public_Health_and_Safety/")
    meta = json.loads((root / (barometer[0] + ".source.json")).read_text())
    assert meta["landing_page"] == f"{server}/samhsa/report/bhb-nh-6"
    assert meta["extra"]["followed_from"] == meta["landing_page"]
    assert any(f.startswith("Legislative_Watch/") and "House-Record" in f for f in files)
    assert any(f.startswith("Public_Health_and_Safety/") and f.endswith(".csv") for f in files)
    # filed by topic: a right-to-know opinion goes to Right_to_Know, not Courts
    assert any(f.startswith("Right_to_Know/") and "Doe-v-Town-of-Exeter" in f for f in files)
    assert any(f.startswith("Privacy_and_Surveillance/") for f in files)

    report = Path(stats["report"]).read_text()
    assert "robots.txt disallows" in report             # /private/secret.pdf
    assert "got a web page" in report                   # fake.pdf
    assert "too large" in report                        # huge.pdf
    assert not list(root.rglob("*.part"))
    assert not any((root / "_index" / "staging").iterdir())

    # every kept file has provenance
    for f in files:
        meta = json.loads((root / (f + ".source.json")).read_text())
        assert meta["url"].startswith("http") and len(meta["sha256"]) == 64
    # the duplicate's other URL is preserved on the kept copy
    dup = [json.loads(p.read_text()) for p in root.rglob("*.source.json")
           if "also_found_at" in json.loads(p.read_text())]
    assert len(dup) == 1
    urls = {dup[0]["url"]} | {a["url"] for a in dup[0]["also_found_at"]}
    assert urls == {f"{server}/files/fr.pdf", f"{server}/files/fr_copy.pdf"}
    with open(root / "_index" / "manifest.csv") as fh:
        assert len(list(csv.DictReader(fh))) == 7

    again = run(cfg)
    assert again["new"] == 0 and again["already_had"] >= 8


def test_dry_run_downloads_nothing(server, tmp_path):
    stats = run(config(server, tmp_path), dry_run=True)
    assert stats["new"] == 0 and stats["kept"] > 0
    assert "would download" in Path(stats["report"]).read_text()
    assert not [p for p in tmp_path.rglob("*.pdf")]


def test_only_filter(server, tmp_path):
    stats = run(config(server, tmp_path), only=["courtlistener"])
    assert stats["new"] == 1


def test_scoring_picks_beat_and_threshold():
    cfg = __import__("yaml").safe_load((Path(__file__).parent.parent / "config.yaml").read_text())
    sc = Scorer(cfg["scoring"])
    c = sc.score(Candidate(url="u", title="Right-to-Know denial log", source="t",
                           description="New Hampshire RSA 91-A public records", file_type="pdf"))
    assert c.beat == "Right_to_Know" and sc.keep(c)
    junk = sc.score(Candidate(url="u", title="Lunch menu", source="t", file_type="pdf"))
    assert not sc.keep(junk)


def test_filenames_cannot_escape_archive(tmp_path):
    a = Archive(tmp_path)
    c = Candidate(url="http://x/a.pdf", title="../../../etc/passwd", source="../evil")
    p = a.final_path(c, "pdf", "0" * 64, __import__("datetime").datetime(2026, 1, 1))
    assert tmp_path.resolve() in p.parents
    assert slugify("../../x") == "x"


def test_dead_sources_are_reported(tmp_path):
    cfg = config("http://127.0.0.1:9", tmp_path)       # nothing listens on port 9
    cfg["http"]["timeout_seconds"] = 2
    stats = run(cfg, only=["federal_register"])
    assert stats["found"] == 0 and stats["source_errors"] == 1
    assert "| 1 | 0 |" in Path(stats["report"]).read_text()


def test_dead_crawler_seed_is_a_source_error(tmp_path):
    cfg = config("http://127.0.0.1:9", tmp_path)
    cfg["http"]["timeout_seconds"] = 2
    stats = run(cfg, only=["crawler"])
    assert stats["source_errors"] == 1


def test_follow_hosts_limits_page_follower(server, tmp_path):
    cfg = config(server, tmp_path)
    cfg["sources"]["datagov"]["follow_hosts"] = ["somewhere-else.example"]
    stats = run(cfg, only=["datagov"], dry_run=True)
    report = Path(stats["report"]).read_text()
    assert "Barometer_Volume6.pdf" not in report          # page not opened
    assert "skipped: .html not allowed" in report         # left as a page


def test_score_cap_and_require_nh(server, tmp_path):
    cfg = config(server, tmp_path)
    cfg["sources"]["internet_archive"]["score_cap"] = 6
    stats = run(cfg, only=["internet_archive"], dry_run=True)
    scores = [int(l.split("|")[1]) for l in Path(stats["report"]).read_text().splitlines()
              if l.startswith("| ") and l.split("|")[1].strip().isdigit() and "internet_archive" in l]
    assert scores and max(scores) <= 6

    cfg = config(server, tmp_path / "nh")
    cfg["scoring"]["nh_terms"] = ["Vermont"]         # fixture never mentions it
    stats = run(cfg, only=["datagov"], dry_run=True)
    assert stats["found"] == 2 and stats["kept"] == 0    # stops.csv + followed PDF

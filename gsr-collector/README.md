# GSR Collector

Finds public documents and datasets that matter to Granite State Report,
downloads them, and files them into the GSR archive with a record of where each
one came from. Free tools only: Python, `requests`, `PyYAML`, and `rclone` for
Google Drive.

## What it does on each run

1. **Find.** Asks each source for candidates: data.gov datasets, Federal
   Register documents, CourtListener opinions from NH courts, Internet Archive
   items, and documents linked from NH government pages.
2. **Score.** Each candidate is scored against the GSR beats in `config.yaml`
   (Right to Know, Courts, Legislative Watch, Privacy and Surveillance, and
   the rest). Title hits count three times as much as description hits. NH
   mentions and data files (CSV, XLSX) score extra. Anything under
   `min_score`, or matching no beat, is skipped.
3. **Download, best first.** The highest scores go first, until a run limit is
   hit. Every file streams to a temp file and only moves into place once it
   is complete. Downloads stop at `max_file_mb`.
4. **File.** Each file lands in its beat folder with a `.source.json` sidecar.
5. **Report.** Each run writes a Markdown table of everything it saw and what
   it did with each item.

## The archive

```
GSR_Archive/
  Right_to_Know/2026-10/2026-10-16_courtlistener_Doe-v-Town-of-Exeter-2026-08-15_1d8882b8.pdf
  Right_to_Know/2026-10/2026-10-16_courtlistener_Doe-v-Town-of-Exeter-2026-08-15_1d8882b8.pdf.source.json
  Courts/ ...  Legislative_Watch/ ...  Privacy_and_Surveillance/ ...
  _index/
    archive.sqlite        dedupe index (URL and SHA-256)
    manifest.csv          one row per file: beat, score, title, publisher, URL, hash
    runs/                 one report per run
```

(The example filename is from the test suite, not a real case.)

The sidecar records the source URL, the landing page, the publisher, the
publication date, the retrieval time (UTC), the SHA-256 hash, and the terms
that matched. If the same bytes turn up at a second URL, the file is kept once
and the second URL goes into `also_found_at`. Before you cite a file, use the
sidecar to go back to the original source.

## Install

```
cd gsr-collector
pip install -r requirements.txt
```

## Use

```
python -m gsr_collector --dry-run             # find and score only, download nothing; read the report
python -m gsr_collector                       # full run into ~/GSR_Archive
python -m gsr_collector --only courtlistener  # one source
python -m gsr_collector --archive /path/to/GSR_Archive
```

Re-running is safe. A URL already in the index is not fetched again, and
identical bytes are never stored twice.

## Put it in Google Drive

**On your computer:** install rclone (https://rclone.org/downloads/), then run
`rclone config`. Create a new remote named `gdrive` with storage type `drive`
and scope `drive.file`, and sign in as granitestatereport@gmail.com. Then run:

```
scripts/run_and_sync.sh          # harvest, then copy to Drive:/GSR_Archive
```

The sync uses `rclone copy`, never `sync`, so nothing you delete locally is
ever deleted from Drive.

## Run it automatically

**On your computer (cron):** add `47 5 * * 1 /path/to/gsr-collector/scripts/run_and_sync.sh`
to your crontab to run every Monday.

**On GitHub, with no computer on:** the workflow
`.github/workflows/gsr-collector.yml` runs Mondays at 10:47 UTC, and you can
also start it from the Actions tab.

1. Set up rclone on your computer as above.
2. Copy the full text of your rclone config file (`rclone config file` prints
   where it is).
3. In the GitHub repo, go to Settings > Secrets and variables > Actions > New
   repository secret. Name it `RCLONE_CONF` and paste the text.
4. Optional: add a `COURTLISTENER_TOKEN` secret (a free account at
   courtlistener.com) for higher rate limits.

Each run first pulls `_index` down from Drive, so files already archived are
skipped. It pushes the new files up, and the run report appears on the
workflow's summary page. The `RCLONE_CONF` secret gives access to your Drive.
Keep the repository private, or use `drive.file` scope so it can only touch
files rclone created.

## Tune it

All tuning happens in `config.yaml`:

- **Pickier or broader:** change `scoring.min_score`.
- **New beat or term:** add it under `scoring.beats`. The beat name becomes
  the folder name.
- **New site:** add a `crawler.seeds` entry. Point it at the page that lists
  the documents (reports, minutes, audits), not the home page. Pages are
  followed only on that seed's domain.
- **New CKAN portal:** add an entry under `ckan.portals`. Many state and city
  open-data portals run CKAN, so check whether a portal does before adding it.
- **Bulk datasets:** raise `limits.max_file_mb` and `limits.max_run_gb`.

## Rules it follows

- Obeys robots.txt and waits `delay_seconds` between requests to the same
  host.
- Identifies itself with the GSR address in the User-Agent, so site operators
  can reach you.
- Public, unauthenticated pages only. It does not log in, solve CAPTCHAs, or
  get around paywalls.
- Downloaded files are never opened or run. If a link meant to be a document
  returns a web page (a login or error page), the result is thrown away.
- Filenames are sanitized and can't be written outside the archive.

## Status of the sources (read before relying on it)

The tool was built in a session whose network blocked every source host, so
**none of the live endpoints has been tested from here**. Each one is marked
`VERIFY` in `config.yaml`. The code follows each service's published API
(CKAN Action API, Federal Register API v1, CourtListener REST v4, Internet
Archive advancedsearch and metadata). The tests run the whole pipeline
against a local imitation of each service. Your first real step is
`python -m gsr_collector --dry-run`, then read the report in
`_index/runs/`. If a source logs errors, the response format has changed and
that connector needs adjusting.

The three crawler seeds (gc.nh.gov, courts.nh.gov, doj.nh.gov) start at
each site's home page. Open them in a browser and replace each with the
specific page that lists the documents you want.

## Tests

```
pip install pytest
python -m pytest
```

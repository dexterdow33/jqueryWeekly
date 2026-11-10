# GSR Collector: Live Dry Run Report

**Run:** 2026-11-10, 12:22 UTC, `python -m gsr_collector --dry-run` with every source enabled
**Ran from:** a Claude Code cloud server, using the environment "jqueryWeekly (GSR Collector)"
**Downloads:** none. A dry run only finds and scores.

## Result

| Source errors | Found | Kept (score ≥ 5) | Unique files kept | Would download | Skipped |
|---|---|---|---|---|---|
| 11 | 1,964 | 262 | 117 | 105 | 12 (web pages, not files) |

"Kept" counts the same file once for each query that found it. "Unique files kept" counts each file once.

## Source by source

| Source | Live result | What changed |
|---|---|---|
| data.gov | **Works.** 76 unique files kept. | The CKAN API is gone: `catalog.data.gov/api/3/action/package_search` returns 404. I rewrote the connector for the new JSON search at `catalog.data.gov/search` (`per_page`, `after` cursor, DCAT `distribution[].downloadURL`). One record had `distribution: null`; the connector now skips records like that instead of crashing. |
| Federal Register | **Works.** 16 kept. | None needed. |
| Internet Archive | **Works.** 25 kept. | None needed. See the caution below. |
| CourtListener | **Blocked: 401.** | v4 search now requires a token. The token saved in this session was rejected with "Invalid username/password." That is the HTTP Basic auth error, so the token was probably saved as a username/password instead of a token. I checked the court IDs (`nh` = Supreme Court of New Hampshire, `nhd` = D. New Hampshire) and the response format through the CourtListener connector; both match the code. |
| NH Supreme Court opinions (crawler) | **Blocked: 403**, Akamai "Access Denied". | New seed: `courts.nh.gov/our-courts/supreme-court/orders-and-opinions/opinions/2026` |
| NH Judicial Branch publications (crawler) | **Blocked: 403**, Akamai. | New seed: `courts.nh.gov/media/resources-media/available-publications` |
| NH DOJ (crawler) | **Blocked: 403**, Akamai. | New seed: `doj.nh.gov/resources`, crawled 2 levels deep under `/resources` (reports, AG opinions, officer-involved shooting reports) |
| NH House Record (crawler) | **Blocked**: connection made, then an empty reply. | Seed is still `gc.nh.gov/`, now following only `/house` pages. Web search found the House Record PDFs but not the index page that lists them. The crawler now recognizes `viewer.aspx?fileName=...pdf` links, which is how gc.nh.gov serves the House Record. |

The 11 source errors are 7 CourtListener queries and 4 blocked seeds.

**About the seed URLs:** they come from web search results on 2026-11-10. None could be opened from the cloud server, so each one still has to load in your browser before you rely on it. The NH sites appear to refuse cloud servers in general, not this tool specifically. Expect the crawler to work from a home connection; GitHub Actions also runs from cloud servers, so it will probably be refused the same way.

## What the kept files look like

| Beat | Files |
|---|---|
| Constitutional_Law | 40 |
| Public_Health_and_Safety | 32 |
| Legislative_Watch | 11 |
| Government_Accountability | 11 |
| Privacy_and_Surveillance | 11 |
| Economic_Inequality | 4 |
| Right_to_Know | 4 |
| Courts | 3 |
| Technology_AI | 1 |

**Problems a reader of this archive needs to know about:**

1. **Internet Archive items are uploads by members of the public, not official releases.** 21 of the 25 are Congressional Research Service reports mirrored as `crs-*` items. The CRS publishes these itself, so cite the CRS copy, not the mirror. Two are titled *New Hampshire High-Speed Public Accountability Act (Draft Legislation - RSA 91-A:2-c)* and *New Hampshire Retail Spatial Dignity, Pediatric Sightline, and Recovery Protection Act (Draft Legislation)*. Nothing shows they were filed as bills. They are uploads of unknown authorship. Do not describe them as legislation without checking gc.nh.gov.
2. **Internet Archive dominates the top scores.** Its titles are long and keyword-heavy, so the top 15 scores are all Internet Archive items. Lowering `score_bonus` for that source, or raising `min_score`, would rebalance this.
3. **Constitutional_Law is inflated.** 38 of the 40 are national *Civil Rights Data Collection* tables (school discipline, harassment, arrests) from data.gov. They match on "civil rights" plus the CSV bonus and are not NH-specific; NH rows may be inside. Move "civil rights" to a different beat, or require an NH mention for data.gov, if you don't want these.
4. **Most Federal Register hits are generic federal notices** ("Privacy Act of 1974; System of Records", Medicare payment rules). They are on-beat, but few are about NH.
5. **The skipped 12** are data.gov links to `.html` pages, which are not documents.

## Code changes in this round

- `sources/datagov.py`: new connector for the current data.gov search API. The CKAN connector stays for other portals, turned off by default.
- `sources/crawler.py`: detects documents behind `viewer.aspx?fileName=` links, and counts a dead seed as a source error instead of a quiet warning.
- `sources/courtlistener.py`: the search query that found an opinion now goes into its description, so opinions file by topic rather than all under Courts.
- `config.yaml`: new seeds, and each source marked with its live-check date.
- Tests: 7 pass, including the live data.gov response shape, a `distribution: null` record, the House Record viewer link, and a dead seed.

## To unblock the rest

1. **CourtListener:** in the environment's network secrets, re-save the CourtListener credential for `www.courtlistener.com` as a **token** (not username/password). Use header `Authorization` and prefix `Token`. The token is on your CourtListener account page.
2. **NH sites:** run `python -m gsr_collector --only crawler --dry-run` from your own computer, then open the report.

---

## Full candidate table (raw run report)

| source errors | found | kept (scored high enough) | new files | duplicates | already archived | skipped | failed | MB downloaded |
|---|---|---|---|---|---|---|---|---|
| 11 | 1964 | 262 | 0 | 0 | 0 | 12 | 0 | 0.0 |

| score | beat | title | source | status |
|---|---|---|---|---|
| 20 | Legislative_Watch | [State Regulation of Foreign Ownership of U.S. Land: January 2023 to July 2024 (LSB11013, v2, August ](https://archive.org/download/crs-lsb11013.2/LSB11013.2.pdf) | internet_archive | would download |
| 18 | Legislative_Watch | [New Hampshire High-Speed Public Accountability Act (Draft Legislation - RSA 91-A:2-c) - nh_high_spee](https://archive.org/download/nh_high_speed_public_accountability_act/nh_high_speed_public_accountability_act.pdf) | internet_archive | would download |
| 18 | Legislative_Watch | [New Hampshire High-Speed Public Accountability Act (Draft Legislation - RSA 91-A:2-c) - nh_high_spee](https://archive.org/download/nh_high_speed_public_accountability_act/nh_high_speed_public_accountability_act_poster.pdf) | internet_archive | would download |
| 17 | Government_Accountability | [Overview of Federal Criminal Laws Prohibiting Interference with Voting (LSB11125, v2, March 15, 2024](https://archive.org/download/crs-lsb11125.2/LSB11125.2.pdf) | internet_archive | would download |
| 14 | Courts | [Birthright Citizenship: Litigation Status Update (LSB11414, v2, April 3, 2026) - LSB11414.2.pdf](https://archive.org/download/crs-lsb11414.2/LSB11414.2.pdf) | internet_archive | would download |
| 14 | Constitutional_Law | [Postponing Federal Elections and the COVID-19 Pandemic: Legal Considerations (LSB10425, v3, March 20](https://archive.org/download/crs-lsb10425.3/LSB10425.3.pdf) | internet_archive | would download |
| 13 | Constitutional_Law | [Election Policy Fundamentals: Single-Member House Districts (IF12567, v3, January 12, 2024) - IF1256](https://archive.org/download/crs-if12567.3/IF12567.3.pdf) | internet_archive | would download |
| 12 | Government_Accountability | [The Temporary Assistance for Needy Families (TANF) Block Grant: Responses to Frequently Asked Questi](https://archive.org/download/crs-rl32760.232/RL32760.232.pdf) | internet_archive | would download |
| 11 | Legislative_Watch | [New Hampshire Retail Spatial Dignity, Pediatric Sightline, and Recovery Protection Act (Draft Legisl](https://archive.org/download/nh_retail_spatial_dignity_act/nh_retail_spatial_dignity_act.pdf) | internet_archive | would download |
| 11 | Government_Accountability | [Audits of EITC Returns: By the Numbers (IN11952, v3, June 13, 2022) - IN11952.3.pdf](https://archive.org/download/crs-in11952.3/IN11952.3.pdf) | internet_archive | would download |
| 10 | Courts | [Continuing Legal Education: What’s Required and Opportunities for Members and Staff to Satisfy Those](https://archive.org/download/crs-lsb10278.5/LSB10278.5.pdf) | internet_archive | would download |
| 10 | Government_Accountability | [Implementation of the Veterans Choice Program (VCP) (IF10563, v4, July 12, 2017) - IF10563.4.pdf](https://archive.org/download/crs-if10563.4/IF10563.4.pdf) | internet_archive | would download |
| 9 | Courts | [State Laws Restricting or Prohibiting Abortion (LSB10779, v9, March 22, 2023) - LSB10779.9.pdf](https://archive.org/download/crs-lsb10779.9/LSB10779.9.pdf) | internet_archive | would download |
| 9 | Legislative_Watch | [Estimated “Direct Payments” by State Under the House and Senate Versions of the American Rescue Plan](https://archive.org/download/crs-in11628.2/IN11628.2.pdf) | internet_archive | would download |
| 9 | Legislative_Watch | [Election Policy Fundamentals: At-Large House Districts (IF12568, v2, January 12, 2024) - IF12568.2.p](https://archive.org/download/crs-if12568.2/IF12568.2.pdf) | internet_archive | would download |
| 9 | Public_Health_and_Safety | [Full Practice Authority for VA Registered Nurse Anesthetists (CRNAs) During the COVID-19 Pandemic (I](https://archive.org/download/crs-in11408.1/IN11408.1.pdf) | internet_archive | would download |
| 8 | Legislative_Watch | [State of New Hampshire Manual for the General Court, 1995 - micro_IA40706953_0081_micro_jp2.zip](https://archive.org/download/micro_IA40706953_0081/micro_IA40706953_0081_micro_jp2.zip) | internet_archive | would download |
| 8 | Public_Health_and_Safety | [Certified Community Behavioral Health Clinics (CCBHCs) (IF12494, v1, September 15, 2023) - IF12494.1](https://archive.org/download/crs-if12494.1/IF12494.1.pdf) | internet_archive | would download |
| 8 | Legislative_Watch | [Core Based Statistical Areas (IF12704, v1, July 3, 2024) - IF12704.1.pdf](https://archive.org/download/crs-if12704.1/IF12704.1.pdf) | internet_archive | would download |
| 8 | Legislative_Watch | [U.S. Senate Vacancies: How Are They Filled? (IF11907, v5, July 16, 2024) - IF11907.5.pdf](https://archive.org/download/crs-if11907.5/IF11907.5.pdf) | internet_archive | would download |
| 8 | Privacy_and_Surveillance | [Tracking COVID-19 Vaccines: U.S. Data Systems and Related Issues (IN11584, v2, January 28, 2021) - I](https://archive.org/download/crs-in11584.2/IN11584.2.pdf) | internet_archive | would download |
| 7 | Public_Health_and_Safety | [2018 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/cbhsq-reports/NewHampshire-2018.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2013 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/URSTables2013/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2014 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/URSTables2014/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2025 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/reports/rpt57219/New%20Hampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2021 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/reports/rpt39421/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2010 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/URSTables2010/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2022 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/reports/rpt42766/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2011 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/URSTables2011/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2023 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/reports/rpt53132/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2012 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/URSTables2012/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2017 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/cbhsq-reports/NewHampshire-2017.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2015 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/NewHampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2016 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/NewHampshire-2016.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2019 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/reports/rpt27959/New%20Hampshire%202019%20URS%20Output%20Tables/New%20Hampshire%202019%20URS%20Output%20Tables.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2024 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/reports/rpt56406/New%20Hampshire.pdf) | data_gov | would download |
| 7 | Public_Health_and_Safety | [2020 URS Output Tables for New Hampshire - New Hampshire](https://www.samhsa.gov/data/sites/default/files/reports/rpt35311/NewHampshire.pdf) | data_gov | would download |
| 7 | Technology_AI | [Medical Devices; Hematology and Pathology Devices; Classification of the Digital Cervical Cytology S](https://www.govinfo.gov/content/pkg/FR-2026-11-05/pdf/2026-22593.pdf) | federal_register | would download |
| 7 | Economic_Inequality | [Major Disaster Assistance from the DRF: New Hampshire (IF10087, v5, March 6, 2017) - IF10087.5.pdf](https://archive.org/download/crs-if10087.5/IF10087.5.pdf) | internet_archive | would download |
| 6 | Public_Health_and_Safety | [2021 Uniform Reporting System (URS) Table For New Hampshire - Official Government Data Source](https://www.samhsa.gov/data/report/2021-uniform-reporting-system-urs-table-new-hampshire) | data_gov | skipped: .html not allowed |
| 6 | Government_Accountability | [New Hampshire High Resolution Wind Resource - 1. New Hampshire High Resolution Wind Resource shape f](https://data.openei.org/files/306/newhampshirewindhighresolution.zip) | data_gov | would download |
| 6 | Government_Accountability | [Visitor Spending Effects Data Package, 2024 - segment_shares_monthly.csv](https://irma.nps.gov/DataStore/DownloadFile/753799?Reference=2316680) | data_gov | would download |
| 6 | Government_Accountability | [Visitor Spending Effects Data Package, 2024 - profile_summary.csv](https://irma.nps.gov/DataStore/DownloadFile/753800?Reference=2316680) | data_gov | would download |
| 6 | Government_Accountability | [Visitor Spending Effects Data Package, 2024 - trip_characteristics.csv](https://irma.nps.gov/DataStore/DownloadFile/753803?Reference=2316680) | data_gov | would download |
| 6 | Government_Accountability | [Visitor Spending Effects Data Package, 2024 - spending_profiles.csv](https://irma.nps.gov/DataStore/DownloadFile/753801?Reference=2316680) | data_gov | would download |
| 6 | Right_to_Know | [Electronic Payments for FOIA Requests](https://www.govinfo.gov/content/pkg/FR-2026-10-30/pdf/2026-22165.pdf) | federal_register | would download |
| 6 | Economic_Inequality | [States Opting Out of COVID-19 Unemployment Insurance (UI) Agreements (IN11679, v4, August 20, 2021) ](https://archive.org/download/crs-in11679.4/IN11679.4.pdf) | internet_archive | would download |
| 6 | Economic_Inequality | [H.R. 5376 Universal Paid Family and Medical Leave Benefit Formula, and the Distribution of Workers a](https://archive.org/download/crs-in11783.1/IN11783.1.pdf) | internet_archive | would download |
| 6 | Public_Health_and_Safety | [Microbeads: An Emerging Water Quality Issue (IF10451, v2, August 11, 2016) - IF10451.2.pdf](https://archive.org/download/crs-if10451.2/IF10451.2.pdf) | internet_archive | would download |
| 5 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, Volume 4 - Official Government Data Source](https://www.samhsa.gov/data/report/behavioral-health-barometer-new-hampshire-volume-4) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [2011 State Profile — New Hampshire - Official Government Data Source](https://www.samhsa.gov/data/report/2011-state-profile-new-hampshire) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [2012 State Profile - New Hampshire - Official Government Data Source](https://www.samhsa.gov/data/report/2012-state-profile-new-hampshire) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, Volume 5 - Official Government Data Source](https://www.samhsa.gov/data/report/behavioral-health-barometer-new-hampshire-volume-5) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [New Hampshire: 2010-2012 NSDUH substate estimates - Official Government Data Source](https://www.samhsa.gov/data/report/new-hampshire-2010-2012-nsduh-substate-estimates) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, Volume 6 - Official Government Data Source](https://www.samhsa.gov/data/report/behavioral-health-barometer-new-hampshire-volume-6) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, 2014 - Official Government Data Source](https://www.samhsa.gov/data/report/behavioral-health-barometer-new-hampshire-2014) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, 2013 - Official Government Data Source](https://www.samhsa.gov/data/report/behavioral-health-barometer-new-hampshire-2013) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, 2015 - Official Government Data Source](https://www.samhsa.gov/data/report/behavioral-health-barometer-new-hampshire-2015) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [New Hampshire (NH) - Official Government Data Source](https://www.samhsa.gov/data/report/new-hampshire-nh-1) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [New Hampshire (NH) - Official Government Data Source](https://www.samhsa.gov/data/report/new-hampshire-nh) | data_gov | skipped: .html not allowed |
| 5 | Constitutional_Law | [2015-16 Harassment or Bullying by Basis Category Civil Rights Data Collection - On Basis of Race - R](https://civilrightsdata.ed.gov/assets/downloads/2015-2016/Harassment-Bullying-on-basis-of-race-reported.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2015-16 Harassment or Bullying by Basis Category Civil Rights Data Collection - On Basis of Disabili](https://civilrightsdata.ed.gov/assets/downloads/2015-2016/Harassment-Bullying-on-basis-of-disability-reported.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2015-16 Harassment or Bullying by Basis Category Civil Rights Data Collection - On Basis of Race - D](https://civilrightsdata.ed.gov/assets/downloads/2015-2016/Harassment-Bullying-on-basis-of-race-disciplined.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2015-16 Harassment or Bullying by Basis Category Civil Rights Data Collection - On Basis of Sex - Re](https://civilrightsdata.ed.gov/assets/downloads/2015-2016/Harassment-Bullying-on-basis-of-sex-reported.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2015-16 Harassment or Bullying by Basis Category Civil Rights Data Collection - Allegations of Haras](https://civilrightsdata.ed.gov/assets/downloads/2015-2016/Allegations-of-Harassment-or-Bullying.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2015-16 Harassment or Bullying by Basis Category Civil Rights Data Collection - On Basis of Sex - Di](https://civilrightsdata.ed.gov/assets/downloads/2015-2016/Harassment-Bullying-on-basis-of-sex-disciplined.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2015-16 Harassment or Bullying by Basis Category Civil Rights Data Collection - On Basis of Disabili](https://civilrightsdata.ed.gov/assets/downloads/2015-2016/Harassment-Bullying-on-basis-of-disability-disciplined.xlsx) | data_gov | would download |
| 5 | Right_to_Know | [Crime Data from 2020 to 2024 - csv](https://data.lacity.org/api/v3/views/2nrs-mtv8/export.csv?accessType=DOWNLOAD) | data_gov | would download |
| 5 | Privacy_and_Surveillance | [Crimes - 2001 to Present - csv](https://data.cityofchicago.org/api/v3/views/ijzp-q8t2/export.csv?accessType=DOWNLOAD) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Arrests Civil Rights Data Collection - School-Related Arrests without disability - 2017-18 A](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Arrests/School-Related-Arrest/School-Related-Arrest_by-no-disability.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Arrests Civil Rights Data Collection - School-Related Arrests by disability - 2017-18 Arrest](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Arrests/School-Related-Arrest/School-Related-Arrest_by-disability.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Arrests Civil Rights Data Collection - Referred to Law Enforcement by disability - 2017-18 A](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Arrests/Referred-to-Law-Enforcement/Referred-to-Law-Enforcement_by-disability.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Arrests Civil Rights Data Collection - School-Related Arrests with and without disability - ](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Arrests/School-Related-Arrest/School-Related-Arrest_by-disability-and-no.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Arrests Civil Rights Data Collection - Referred to Law Enforcement with and without disabili](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Arrests/Referred-to-Law-Enforcement/Referred-to-Law-Enforcement_by-disability-and-no.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Arrests Civil Rights Data Collection - Offenses - 2017-18 Arrests Civil Rights Data Collecti](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Offenses/Offenses.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Arrests Civil Rights Data Collection - Referred to Law Enforcement without disability - 2017](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Arrests/Referred-to-Law-Enforcement/Referred-to-Law-Enforcement_by-no-disability.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Harassment or Bullying Civil Rights Data Collection - On basis of sex - disciplined - 2017-1](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Harassment-or-Bullying/Harassment-Bullying-on-basis-of-sex_disciplined.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Harassment or Bullying Civil Rights Data Collection - On basis of sex - reported - 2017-18 H](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Harassment-or-Bullying/Harassment-Bullying-on-basis-of-sex_reported.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Harassment or Bullying Civil Rights Data Collection - On basis of race - disciplined - 2017-](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Harassment-or-Bullying/Harassment-Bullying-on-basis-of-race_disciplined.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Harassment or Bullying Civil Rights Data Collection - On basis of race - reported - 2017-18 ](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Harassment-or-Bullying/Harassment-Bullying-on-basis-of-race_reported.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Harassment or Bullying Civil Rights Data Collection - On basis of disability - reported - 20](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Harassment-or-Bullying/Harassment-Bullying-on-basis-of-disability_reported.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Harassment or Bullying Civil Rights Data Collection - On basis of disability - disciplined -](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Climate/Harassment-or-Bullying/Harassment-Bullying-on-basis-of-disability_discplined.xlsx) | data_gov | would download |
| 5 | Legislative_Watch | [Traffic Crashes - Crashes - csv](https://data.cityofchicago.org/api/v3/views/85ca-t3if/export.csv?accessType=DOWNLOAD) | data_gov | would download |
| 5 | Privacy_and_Surveillance | [Nutrition, Physical Activity, and Obesity - Behavioral Risk Factor Surveillance System - csv](https://data.cdc.gov/api/v3/views/hn4x-zwk7/export.csv?accessType=DOWNLOAD) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Geometry - 2013-14 Mathematics and Sc](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Geometry.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Biology - 2013-14 Mathematics and Sci](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Biology.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Algebra I Grade 9-10 - 2013-14 Mathem](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Algebra-I-9-10.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Algebra II - 2013-14 Mathematics and ](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Algebra-II.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Chemistry - 2013-14 Mathematics and S](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Chemistry.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Calculus - 2013-14 Mathematics and Sc](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Calculus.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Algebra I Grade 7-8 - 2013-14 Mathema](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Algebra-I-7-8.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Algebra I Grade 11-12 - 2013-14 Mathe](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Algebra-I-11-12.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Advanced Mathematics - 2013-14 Mathem](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Advanced-Mathematics.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Schools Offering Mathematics and Scie](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Classes-in-Mathematics-and-Science.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2013-14 Mathematics and Science Civil Rights Data Collection - Physics - 2013-14 Mathematics and Sci](https://civilrightsdata.ed.gov/assets/downloads/2013-2014/Enrollment-in-Physics.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Student Enrollment Civil Rights Data Collection - Enrollment-Section-504-onlyxlsx - 2017-18 ](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/Student-Enrollment/All-Enrollment/Enrollment-Section-504-only.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Student Enrollment Civil Rights Data Collection - Preschool Enrollment - 2017-18 Student Enr](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/Student-Enrollment/Preschool-Enrollment/Preschool-Enrollment.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Student Enrollment Civil Rights Data Collection - Enrollment-Limited-English-Proficientxlsx ](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/Student-Enrollment/All-Enrollment/Enrollment-Limited-English-Proficient.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Student Enrollment Civil Rights Data Collection - Enrollment-IDEAxlsx - 2017-18 Student Enro](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/Student-Enrollment/All-Enrollment/Enrollment-IDEA.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 Student Enrollment Civil Rights Data Collection - Enrollment-Overallxlsx - 2017-18 Student E](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/Student-Enrollment/All-Enrollment/Enrollment-Overall.xlsx) | data_gov | would download |
| 5 | Economic_Inequality | [FFIEC Call Reports - FFIEC Call Reports Balance Sheet Income Statement Past Due Four Periods](https://cdr.ffiec.gov/public/PWS/DownloadBulkData.aspx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 School Staff Civil Rights Data Collection - Teacher Certification and Years of Experience - ](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Staff/Classroom-Teachers/Teacher-Certification-and-Years-of-Experience.xlsx) | data_gov | would download |
| 5 | Constitutional_Law | [2017-18 School Staff Civil Rights Data Collection - Counselors High School - 2017-18 School Staff Ci](https://civilrightsdata.ed.gov/assets/downloads/2017-2018/School-Staff/School-Support-Staff/Counselors_High-School.xlsx) | data_gov | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; System of Records](https://www.govinfo.gov/content/pkg/FR-2026-11-09/pdf/2026-22837.pdf) | federal_register | would download |
| 5 | Public_Health_and_Safety | [Medicare and Medicaid Programs; CY 2027 Payment Policies Under the Physician Fee Schedule and Other ](https://www.govinfo.gov/content/pkg/FR-2026-11-09/pdf/2026-22743.pdf) | federal_register | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; Systems of Records](https://www.govinfo.gov/content/pkg/FR-2026-11-04/pdf/2026-22511.pdf) | federal_register | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; Matching Program](https://www.govinfo.gov/content/pkg/FR-2026-11-03/pdf/2026-22357.pdf) | federal_register | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; System of Records](https://www.govinfo.gov/content/pkg/FR-2026-10-30/pdf/2026-22254.pdf) | federal_register | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; Matching Program](https://www.govinfo.gov/content/pkg/FR-2026-10-29/pdf/2026-22015.pdf) | federal_register | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; Matching Program](https://www.govinfo.gov/content/pkg/FR-2026-10-28/pdf/2026-21946.pdf) | federal_register | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; Matching Program](https://www.govinfo.gov/content/pkg/FR-2026-10-28/pdf/2026-21916.pdf) | federal_register | would download |
| 5 | Privacy_and_Surveillance | [Privacy Act of 1974; System of Records](https://www.govinfo.gov/content/pkg/FR-2026-10-26/pdf/2026-21804.pdf) | federal_register | would download |
| 5 | Right_to_Know | [Agency Information Collection Activities: ICE FOIA Request Form, I-902](https://www.govinfo.gov/content/pkg/FR-2026-10-26/pdf/2026-21765.pdf) | federal_register | would download |
| 5 | Right_to_Know | [Medicare Program: Hospital Outpatient Prospective Payment and Ambulatory Surgical Center Payment Sys](https://www.govinfo.gov/content/pkg/FR-2026-11-06/pdf/2026-22739.pdf) | federal_register | would download |
| 5 | Legislative_Watch | [Entergy Operations Inc.; Arkansas Nuclear One, Unit 2; License Amendment Application](https://www.govinfo.gov/content/pkg/FR-2026-11-06/pdf/2026-22711.pdf) | federal_register | would download |
| 5 | Government_Accountability | [NCUA Draft 2027-2028 Budget](https://www.govinfo.gov/content/pkg/FR-2026-10-28/pdf/2026-21948.pdf) | federal_register | would download |
| 5 | Government_Accountability | [Public Meeting of the National Sea Grant Advisory Board](https://www.govinfo.gov/content/pkg/FR-2026-10-08/pdf/2026-20674.pdf) | federal_register | would download |

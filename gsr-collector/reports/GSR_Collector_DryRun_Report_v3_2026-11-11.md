# GSR Collector: Live Dry Run Report, v3 (SAMHSA page follower)

**Runs:** 2026-11-11 at 23:00 UTC (`--only courtlistener --dry-run`) and 23:08 UTC (full `--dry-run`, every source)
**Ran from:** a Claude Code cloud server, using the environment "jqueryWeekly (GSR Collector)", with www.samhsa.gov added to its allowlist
**Downloads:** none. A dry run only finds and scores.
**Replaces:** v2 (2026-11-10). v1 and v2 are kept for comparison.

## CourtListener: still blocked

`--only courtlistener --dry-run` ended with **7 of 7 queries at 401** ("Invalid username/password."), nothing found, exit code 2.

The secret is still being sent as username/password. Three checks show it:

- "Invalid username/password." is CourtListener's error for HTTP Basic credentials. A wrong token sent as `Token …` gets "Invalid token." instead.
- I sent a request that already carried an `Authorization: Token …` header, and the proxy replaced it: the answer was still the Basic error.
- `api/rest/v4/courts/nh/` normally needs no login, but it also returned 401. The proxy attaches the saved secret to every request to www.courtlistener.com, so a bad credential breaks even public endpoints.

The environment shows one secret, "CourtListener API token", but its type isn't visible to me. A form to re-save it opened during this session but expired before it was answered. To fix it: in the environment's network secrets, delete the CourtListener entry and add a new one. Choose **token / bearer**, not username/password, with header `Authorization` and prefix `Token`, and paste the key from your CourtListener account page.

## Page-to-PDF follower

data.gov lists some reports as a web page, not a file. With `follow_pages: true`, the data.gov connector now opens such a page and takes up to 5 documents linked from it, on the same host only. To avoid hitting unrelated sites, it only opens pages on hosts named in `follow_hosts`, currently `www.samhsa.gov`. www.samhsa.gov's robots.txt allows `/data/report/` and `/data/sites/`; it disallows only `/data/all-reports?*` under `/data`.

**Result: of the 12 SAMHSA NH pages skipped in v2, 9 now come through as new PDFs, 1 resolves to a file already in the queue, and 2 have no PDF.** The duplicate is the "2021 Uniform Reporting System (URS) Table For New Hampshire" page. Its PDF (`reports/rpt39421/NewHampshire.pdf`) is the same file data.gov already lists directly as "2021 URS Output Tables for New Hampshire", so it is kept once.

| Report | PDF |
|---|---|
| Behavioral Health Barometer: New Hampshire, 2013 | New_Hampshire_BHBarometer.pdf |
| Behavioral Health Barometer: New Hampshire, 2014 | BHBarometer-NH.pdf |
| Behavioral Health Barometer: New Hampshire, 2015 | 2015_New-Hampshire_BHBarometer.pdf |
| Behavioral Health Barometer: New Hampshire, Volume 4 | NewHampshire_BHBarometer_Volume_4.pdf |
| Behavioral Health Barometer: New Hampshire, Volume 5 | New Hampshire-BH-BarometerVolume5.pdf |
| Behavioral Health Barometer: New Hampshire, Volume 6 | NewHampshire-BH-Barometer_Volume6.pdf |
| 2011 State Profile, New Hampshire | NH11.pdf |
| 2012 State Profile, New Hampshire | NH12.pdf |
| New Hampshire (NH), NSDUH substate estimates 2010 | NSDUHsaeNH2010.pdf |

I spot-checked two (Barometer Volume 6 and NSDUHsaeNH2010). Both returned `application/pdf`, and the files start with `%PDF-`.

**The 2 still skipped have no PDF to find.** "New Hampshire: 2010-2012 NSDUH substate estimates" and the second "New Hampshire (NH)" entry link only to `.htm` tables (`NSDUHsubstateStateTabsNH2012.htm`, `NSDUHsubstate51StateNH2010.htm`). The collector does not archive web pages, so they stay skipped.

A first version of the follower opened every page-type entry data.gov returned, including national IRS, USDA, NCES and Washington State tools. It tried 9 such pages 36 times, because they came back under several queries. With retries, that made 144 failed requests to hosts the network doesn't allow. `follow_hosts` stops that: the final run logged 3 warnings, all gc.nh.gov retries.

## Result

| | v2 | v3 |
|---|---|---|
| Source errors | 11 | 11 (7 CourtListener, 4 NH crawler seeds) |
| Found | 1,991 | 2,027 |
| Unique files kept | 70 | 70 |
| Would download | 58 | **68** |
| Skipped (web pages, not files) | 12 | **2** |
| Run time | not recorded | 144 s |

"Found" moves between runs because the live services return slightly different results.

| Source | Unique files kept |
|---|---|
| data.gov | 28 (26 files, 2 skipped pages) |
| Internet Archive | 25 (capped at score 6) |
| Federal Register | 17 |
| CourtListener | 0 (401) |
| NH court, DOJ and General Court seeds | 0 (blocked from cloud servers) |

| Beat | Files |
|---|---|
| Public_Health_and_Safety | 31 |
| Legislative_Watch | 10 |
| Privacy_and_Surveillance | 9 |
| Government_Accountability | 7 |
| Economic_Inequality | 4 |
| Right_to_Know | 3 |
| Courts | 3 |
| Constitutional_Law | 2 |
| Technology_AI | 1 |

## Still true from v2

1. **Public_Health_and_Safety is mostly SAMHSA.** It holds 16 yearly URS tables plus the 9 new reports. All are real NH data, but this beat is now most of the archive.
2. **Internet Archive items are uploads by members of the public.** Both "New Hampshire … Act (Draft Legislation)" PDFs are still in the queue. Nothing shows either was filed as a bill; check gc.nh.gov before describing them as legislation.
3. **Federal Register hits are mostly generic federal notices.** Setting `require_nh` on that source would cut them to NH-specific notices.
4. **The NH court, DOJ and General Court crawler seeds need a home connection;** those sites refuse cloud servers.

## Code changes in this round

- `sources/datagov.py`: page follower, controlled by `follow_pages`, `max_docs_per_page` and `follow_hosts`. Followed files record their source page in `landing_page` and in `extra.followed_from`, plus the data.gov dataset page.
- `config.yaml`: follower turned on for www.samhsa.gov.
- Tests: 9 pass. New ones cover a followed PDF landing in the right beat with its provenance, an off-site PDF on the same page being ignored, and `follow_hosts` blocking pages on other hosts.

---

## Full candidate table (raw run report)

| source errors | found | kept (scored high enough) | new files | duplicates | already archived | skipped | failed | MB downloaded |
|---|---|---|---|---|---|---|---|---|
| 11 | 2027 | 76 | 0 | 0 | 0 | 2 | 0 | 0.0 |

| score | beat | title | source | status |
|---|---|---|---|---|
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
| 6 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, Volume 4 - NewHampshire_BHBarometer_Volume_4](https://www.samhsa.gov/data/sites/default/files/NewHampshire_BHBarometer_Volume_4.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [2011 State Profile — New Hampshire - NH11](https://www.samhsa.gov/data/sites/default/files/2011%20-%20NSSATS%20State%20Profiles/2011%20-%20NSSATS%20State%20Profiles/NH11.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, Volume 5 - New Hampshire-BH-BarometerVolume5](https://www.samhsa.gov/data/sites/default/files/cbhsq-reports/New%20Hampshire-BH-BarometerVolume5.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [2012 State Profile - New Hampshire - NH12](https://www.samhsa.gov/data/sites/default/files/2012%20-%20NSSATS%20State%20Profiles/2012%20-%20NSSATS%20State%20Profiles/NH12.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, Volume 6 - NewHampshire-BH-Barometer_Volume6](https://www.samhsa.gov/data/sites/default/files/reports/rpt32846/NewHampshire-BH-Barometer_Volume6.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, 2013 - New_Hampshire_BHBarometer](https://www.samhsa.gov/data/sites/default/files/New_Hampshire_BHBarometer.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, 2014 - BHBarometer-NH](https://www.samhsa.gov/data/sites/default/files/State_BHBarometers_2014_2/BHBarometer-NH.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [Behavioral Health Barometer: New Hampshire, 2015 - 2015_New-Hampshire_BHBarometer](https://www.samhsa.gov/data/sites/default/files/2015_New-Hampshire_BHBarometer.pdf) | data_gov | would download |
| 6 | Public_Health_and_Safety | [New Hampshire (NH) - NSDUHsaeNH2010](https://www.samhsa.gov/data/sites/default/files/NSDUHStateEst2009-2010/StateSpecificTables/NSDUHsaeNH2010.pdf) | data_gov | would download |
| 6 | Government_Accountability | [New Hampshire High Resolution Wind Resource - 1. New Hampshire High Resolution Wind Resource shape f](https://data.openei.org/files/306/newhampshirewindhighresolution.zip) | data_gov | would download |
| 6 | Right_to_Know | [Electronic Payments for FOIA Requests](https://www.govinfo.gov/content/pkg/FR-2026-10-30/pdf/2026-22165.pdf) | federal_register | would download |
| 6 | Economic_Inequality | [Major Disaster Assistance from the DRF: New Hampshire (IF10087, v5, March 6, 2017) - IF10087.5.pdf](https://archive.org/download/crs-if10087.5/IF10087.5.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [New Hampshire Retail Spatial Dignity, Pediatric Sightline, and Recovery Protection Act (Draft Legisl](https://archive.org/download/nh_retail_spatial_dignity_act/nh_retail_spatial_dignity_act.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [New Hampshire High-Speed Public Accountability Act (Draft Legislation - RSA 91-A:2-c) - nh_high_spee](https://archive.org/download/nh_high_speed_public_accountability_act/nh_high_speed_public_accountability_act.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [New Hampshire High-Speed Public Accountability Act (Draft Legislation - RSA 91-A:2-c) - nh_high_spee](https://archive.org/download/nh_high_speed_public_accountability_act/nh_high_speed_public_accountability_act_poster.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [State of New Hampshire Manual for the General Court, 1995 - micro_IA40706953_0081_micro_jp2.zip](https://archive.org/download/micro_IA40706953_0081/micro_IA40706953_0081_micro_jp2.zip) | internet_archive | would download |
| 6 | Courts | [Continuing Legal Education: What’s Required and Opportunities for Members and Staff to Satisfy Those](https://archive.org/download/crs-lsb10278.5/LSB10278.5.pdf) | internet_archive | would download |
| 6 | Courts | [Birthright Citizenship: Litigation Status Update (LSB11414, v2, April 3, 2026) - LSB11414.2.pdf](https://archive.org/download/crs-lsb11414.2/LSB11414.2.pdf) | internet_archive | would download |
| 6 | Public_Health_and_Safety | [Certified Community Behavioral Health Clinics (CCBHCs) (IF12494, v1, September 15, 2023) - IF12494.1](https://archive.org/download/crs-if12494.1/IF12494.1.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [Core Based Statistical Areas (IF12704, v1, July 3, 2024) - IF12704.1.pdf](https://archive.org/download/crs-if12704.1/IF12704.1.pdf) | internet_archive | would download |
| 6 | Government_Accountability | [Implementation of the Veterans Choice Program (VCP) (IF10563, v4, July 12, 2017) - IF10563.4.pdf](https://archive.org/download/crs-if10563.4/IF10563.4.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [U.S. Senate Vacancies: How Are They Filled? (IF11907, v5, July 16, 2024) - IF11907.5.pdf](https://archive.org/download/crs-if11907.5/IF11907.5.pdf) | internet_archive | would download |
| 6 | Constitutional_Law | [Postponing Federal Elections and the COVID-19 Pandemic: Legal Considerations (LSB10425, v3, March 20](https://archive.org/download/crs-lsb10425.3/LSB10425.3.pdf) | internet_archive | would download |
| 6 | Economic_Inequality | [States Opting Out of COVID-19 Unemployment Insurance (UI) Agreements (IN11679, v4, August 20, 2021) ](https://archive.org/download/crs-in11679.4/IN11679.4.pdf) | internet_archive | would download |
| 6 | Government_Accountability | [Audits of EITC Returns: By the Numbers (IN11952, v3, June 13, 2022) - IN11952.3.pdf](https://archive.org/download/crs-in11952.3/IN11952.3.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [State Regulation of Foreign Ownership of U.S. Land: January 2023 to July 2024 (LSB11013, v2, August ](https://archive.org/download/crs-lsb11013.2/LSB11013.2.pdf) | internet_archive | would download |
| 6 | Privacy_and_Surveillance | [Tracking COVID-19 Vaccines: U.S. Data Systems and Related Issues (IN11584, v2, January 28, 2021) - I](https://archive.org/download/crs-in11584.2/IN11584.2.pdf) | internet_archive | would download |
| 6 | Economic_Inequality | [H.R. 5376 Universal Paid Family and Medical Leave Benefit Formula, and the Distribution of Workers a](https://archive.org/download/crs-in11783.1/IN11783.1.pdf) | internet_archive | would download |
| 6 | Courts | [State Laws Restricting or Prohibiting Abortion (LSB10779, v9, March 22, 2023) - LSB10779.9.pdf](https://archive.org/download/crs-lsb10779.9/LSB10779.9.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [Estimated “Direct Payments” by State Under the House and Senate Versions of the American Rescue Plan](https://archive.org/download/crs-in11628.2/IN11628.2.pdf) | internet_archive | would download |
| 6 | Legislative_Watch | [Election Policy Fundamentals: At-Large House Districts (IF12568, v2, January 12, 2024) - IF12568.2.p](https://archive.org/download/crs-if12568.2/IF12568.2.pdf) | internet_archive | would download |
| 6 | Public_Health_and_Safety | [Microbeads: An Emerging Water Quality Issue (IF10451, v2, August 11, 2016) - IF10451.2.pdf](https://archive.org/download/crs-if10451.2/IF10451.2.pdf) | internet_archive | would download |
| 6 | Constitutional_Law | [Election Policy Fundamentals: Single-Member House Districts (IF12567, v3, January 12, 2024) - IF1256](https://archive.org/download/crs-if12567.3/IF12567.3.pdf) | internet_archive | would download |
| 6 | Public_Health_and_Safety | [Full Practice Authority for VA Registered Nurse Anesthetists (CRNAs) During the COVID-19 Pandemic (I](https://archive.org/download/crs-in11408.1/IN11408.1.pdf) | internet_archive | would download |
| 6 | Government_Accountability | [The Temporary Assistance for Needy Families (TANF) Block Grant: Responses to Frequently Asked Questi](https://archive.org/download/crs-rl32760.232/RL32760.232.pdf) | internet_archive | would download |
| 6 | Government_Accountability | [Overview of Federal Criminal Laws Prohibiting Interference with Voting (LSB11125, v2, March 15, 2024](https://archive.org/download/crs-lsb11125.2/LSB11125.2.pdf) | internet_archive | would download |
| 5 | Public_Health_and_Safety | [New Hampshire: 2010-2012 NSDUH substate estimates - Official Government Data Source](https://www.samhsa.gov/data/report/new-hampshire-2010-2012-nsduh-substate-estimates) | data_gov | skipped: .html not allowed |
| 5 | Public_Health_and_Safety | [New Hampshire (NH) - Official Government Data Source](https://www.samhsa.gov/data/report/new-hampshire-nh-1) | data_gov | skipped: .html not allowed |
| 5 | Economic_Inequality | [Housing and Community Development Act of 1980: Verification of Eligible Status](https://www.govinfo.gov/content/pkg/FR-2026-11-12/pdf/2026-23003.pdf) | federal_register | would download |
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

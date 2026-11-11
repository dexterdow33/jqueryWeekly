# GSR Collector: Live Dry Run Report, v2 (scoring tuned)

**Run:** 2026-11-10, 17:56 UTC, `python -m gsr_collector --dry-run` with every source enabled
**Ran from:** a Claude Code cloud server, using the environment "jqueryWeekly (GSR Collector)"
**Downloads:** none. A dry run only finds and scores.
**Replaces:** v1 (12:22 UTC the same day), which is kept for comparison.

## Result

| | v1 | v2 |
|---|---|---|
| Source errors | 11 | 11 |
| Found | 1,964 | 1,991 |
| Unique files kept | 117 | **70** |
| Would download | 105 | **58** |
| Skipped (HTML pages, not files) | 12 | 12 |
| Civil Rights Data Collection tables | 38 | **0** |
| Highest Internet Archive score | 20 | **6** |

"Found" moved because the live services returned slightly different results between runs.

## Scoring changes

| Change | Setting | Effect |
|---|---|---|
| Cap Internet Archive | `internet_archive.score_cap: 6` | Internet Archive held all 15 top scores in v1; it now tops out at 6. Most official-source hits score 5 to 7, so public uploads no longer lead the queue. |
| Require an NH mention on data.gov | `datagov.require_nh: true` | data.gov dropped from 76 unique files to 29. I checked all 47 dropped files: 38 were national CRDC tables, and 9 were national or other-city data (NPS visitor spending, crime data from other cities, BRFSS obesity data, FFIEC call reports). None mentioned NH in its title. |
| Move "civil rights" out of Constitutional_Law | Now under `Government_Accountability` | Constitutional_Law dropped from 40 files to 2. I picked Government_Accountability as the closest existing beat; your category plan has no Civil Rights category. Say so if you want it somewhere else. |

`score_cap` and `require_nh` work on any source and are documented in the README. Tests: 8 pass, including one each for the cap and the NH requirement.

## Sources

| Source | Status |
|---|---|
| data.gov | Works: 29 unique files kept |
| Federal Register | Works: 16 kept |
| Internet Archive | Works: 25 kept, capped at 6 |
| CourtListener | **Still 401, "Invalid username/password."** That message is the HTTP Basic auth error. A token sent with the `Token` prefix but simply wrong gets "Invalid token." instead, so the proxy is still sending username/password. The environment shows one saved secret, "CourtListener API token". Its type is not visible to me. Either the proxy hasn't picked up the re-saved version yet (pickup can take up to an hour), or it is still saved as username/password. |
| NH courts, NH DOJ, gc.nh.gov crawler seeds | Blocked from cloud servers, same as v1 (Akamai 403 / empty reply) |

## What's in the archive queue now

| Beat | Files |
|---|---|
| Public_Health_and_Safety | 32 |
| Legislative_Watch | 10 |
| Privacy_and_Surveillance | 9 |
| Government_Accountability | 7 |
| Right_to_Know | 3 |
| Economic_Inequality | 3 |
| Courts | 3 |
| Constitutional_Law | 2 |
| Technology_AI | 1 |

**Still worth knowing:**

1. **Public_Health_and_Safety is mostly one series.** It holds 16 yearly SAMHSA "URS Output Tables for New Hampshire" (2010 to 2025), all scored 7. They are real NH mental-health system data, but one dataset repeated by year.
2. **The 12 skipped items are NH reports this tool can't reach yet.** They are SAMHSA's Behavioral Health Barometer: New Hampshire (several volumes), State Profiles, and NSDUH substate estimates. data.gov lists them as web pages, not files, so they are skipped. Getting them would mean following each page to its PDF, which would be a new feature.
3. **Internet Archive items are still public uploads.** Both "New Hampshire … Act (Draft Legislation)" PDFs are still in the queue at score 6. Nothing shows either was filed. Do not describe them as bills without checking gc.nh.gov.
4. **Federal Register hits are mostly generic federal notices** (Privacy Act system-of-records notices, Medicare rules). They are on-beat, but rarely about NH. A `require_nh` on that source would cut them to the few NH notices, if you want that.

## To finish

1. **CourtListener:** open the environment's network secrets and check that the entry for `www.courtlistener.com` is a token type, with header `Authorization` and prefix `Token`. If it already is, wait an hour and run `python -m gsr_collector --only courtlistener --dry-run`.
2. **NH sites:** run `python -m gsr_collector --only crawler --dry-run` from your own computer.

---

## Full candidate table (raw run report)

| source errors | found | kept (scored high enough) | new files | duplicates | already archived | skipped | failed | MB downloaded |
|---|---|---|---|---|---|---|---|---|
| 11 | 1991 | 74 | 0 | 0 | 0 | 12 | 0 | 0.0 |

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
| 6 | Public_Health_and_Safety | [2021 Uniform Reporting System (URS) Table For New Hampshire - Official Government Data Source](https://www.samhsa.gov/data/report/2021-uniform-reporting-system-urs-table-new-hampshire) | data_gov | skipped: .html not allowed |
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

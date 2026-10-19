"""Every raw data source in one list, plus the helpers that download them.

Used by notebooks/00-download-data.ipynb. Each source lands in data/raw/<group>/<key>/ exactly as
published (no cleaning here), and every file gets a line in data/raw/manifest.csv: URL, download time,
size and SHA-256. Research behind each choice: docs/plans/data-research/ (reports 00-06).

Scope: NYC first, government sources, at least 5 years of history.
"""
import csv
import hashlib
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode

import requests

from common import RAW

MANIFEST = RAW / "manifest.csv"
MANIFEST_COLS = ["group", "key", "file", "url", "downloaded_utc", "bytes", "sha256", "note"]

# bls.gov and some .gov hosts reject scripts that don't look like a browser. A descriptive User-Agent
# plus normal browser Accept headers passes (tested). No personal email in any request.
HEADERS = {
    "User-Agent": "cuny-gap-research/1.0 (portfolio project)",
    "Accept": "*/*",
    "Accept-Language": "en-US",
    "Accept-Encoding": "gzip, deflate",
}

NYC_COUNTIES = ["Bronx", "Kings", "New York", "Queens", "Richmond"]
NYC_FIPS = ["36005", "36047", "36061", "36081", "36085"]

SOCRATA_NY = "https://data.ny.gov"
SOCRATA_NYC = "https://data.cityofnewyork.us"
WAYBACK_PROJ = ("https://web.archive.org/web/{ts}id_/"
                "https://data.ny.gov/api/views/pqm4-9qqb/rows.csv?accessType=DOWNLOAD")


def socrata_export(host: str, dataset: str) -> str:
    """Full-dataset CSV export, exactly as the portal publishes it."""
    return f"{host}/api/views/{dataset}/rows.csv?accessType=DOWNLOAD"


def socrata_query(host: str, dataset: str, **soql) -> str:
    """Filtered CSV through the SoQL API (used when the full table is huge or holds names)."""
    params = {"$limit": 5_000_000, **{f"${k}": v for k, v in soql.items()}}
    return f"{host}/resource/{dataset}.csv?{urlencode(params)}"


# ---------------------------------------------------------------------------------------------
# The registry. One entry = one file. `snapshot=True` marks sources that overwrite themselves
# (no history kept by the publisher), so the file name gets today's date and each run adds a copy.
# ---------------------------------------------------------------------------------------------
YEARS_OEWS = range(18, 26)          # May 2018 - May 2025: the comparable NY-metro window
YEARS_OEWS_RESEARCH = range(2019, 2026)  # state x industry x job, May 2019 - May 2025 (May 2025 posted 2026-05-15)
YEARS_QCEW_BLS = range(2019, 2026)       # BLS QCEW county annual averages (has local government by NAICS)
YEARS_IPEDS = range(2015, 2025)     # awards 2014-15 to 2023-24
OFLC_YEARS = ["2021-22", "2022-23", "2023-24", "2024-25", "2025-26", "2026-27"]
WAYBACK_SNAPSHOTS = {               # NYC projection vintages recovered from the Wayback Machine (report 01)
    "2016-2026": "20210324183534",
    "2018-2028": "20221130141045",
    "2020-2030": "20241104204940",
}
NYSED_OP = "https://www.op.nysed.gov"
NCLEX_PAGE = (NYSED_OP + "/professions/registered-professional-nursing/nursing-education/"
              "new-york-state-nursing-programs/new-york-state-{kind}-nclex-results-{span}")
NCLEX_SPANS = ["2008-2012", "2013-2017", "2018-2022", "2023-2027"]
HIRING_LAB = "https://raw.githubusercontent.com/hiring-lab/job_postings_tracker/master/US/"


def build_registry() -> list[dict]:
    S = []

    def add(group, key, url, file, **extra):
        S.append({"group": group, "key": key, "url": url, "file": file, **extra})

    # --- 1. Jobs and pay over time -------------------------------------------------------------
    for yy in YEARS_OEWS:
        add("jobs", "bls_oews_metro", f"https://www.bls.gov/oes/special-requests/oesm{yy:02d}ma.zip",
            f"oesm{yy:02d}ma.zip", note=f"OEWS May 20{yy:02d}, all metro areas (NY = 35620)")
    add("jobs", "nysdol_oews_regions", socrata_export(SOCRATA_NY, "gkgz-nw24"), "gkgz-nw24.csv",
        snapshot=True, note="NYS DOL wages by region incl. NYC 5 boroughs, entry/experienced wage; overwritten yearly")
    add("jobs", "nysdol_projections", socrata_export(SOCRATA_NY, "pqm4-9qqb"), "pqm4-9qqb.csv",
        snapshot=True, note="Long-term projections, current vintage (NYC 2022-2032)")
    for period, ts in WAYBACK_SNAPSHOTS.items():
        add("jobs", "nysdol_projections_archive", WAYBACK_PROJ.format(ts=ts),
            f"pqm4-9qqb_{period}_wayback{ts}.csv", note=f"NYC {period} vintage, Wayback capture {ts}")
    add("jobs", "nysdol_projections_xlsx", "https://dol.ny.gov/statistics-regional-long-term-occupational-projections",
        "nysdol_ltproj_2022-2032_regions.xlsx", snapshot=True,
        note="Same 2022-32 projections, one sheet per region, plus columns the CSV lacks: 2026 wages, "
             "entry education, Employment Prospects (the page URL serves the xlsx directly)")
    add("jobs", "nysdol_qcew_annual", socrata_export(SOCRATA_NY, "shc7-xcbw"), "shc7-xcbw.csv",
        note="QCEW annual jobs/wages by county x NAICS, 2000-2025")
    add("jobs", "nysdol_ces", socrata_export(SOCRATA_NY, "6k74-dgkb"), "6k74-dgkb.csv",
        note="CES monthly jobs by industry since 1990 (NYC area 93561)")
    add("jobs", "bls_soc_crosswalk", "https://www.bls.gov/soc/2018/soc_2010_to_2018_crosswalk.xlsx",
        "soc_2010_to_2018_crosswalk.xlsx", note="Needed for OEWS 2018-2020 and older projections")
    add("jobs", "bls_ep_education", "https://www.bls.gov/emp/ind-occ-matrix/education.xlsx",
        "education.xlsx", snapshot=True, note="Entry education, experience, training; attainment table 5.3")
    add("jobs", "bls_ep_occupation", "https://www.bls.gov/emp/ind-occ-matrix/occupation.xlsx",
        "occupation.xlsx", snapshot=True, note="National employment, growth and openings by job (Table 1.2); decision D1")
    add("jobs", "bls_soc_structure", "https://www.bls.gov/soc/2018/soc_structure_2018.xlsx",
        "soc_structure_2018.xlsx", note="SOC 2018 hierarchy: major, minor, broad, detailed codes and titles")
    add("jobs", "bls_oews_hybrid", "https://www.bls.gov/oes/oes_2019_hybrid_structure.xlsx",
        "oes_2019_hybrid_structure.xlsx", note="OEWS May 2019-2020 hybrid codes and their SOC 2010 / 2018 parts")

    # --- 1b. Industry -> jobs bridge --
    for t, note in [("CAGDP2", "GDP by county x industry, current dollars (NYC = 5 borough FIPS)"),
                    ("CAGDP9", "Real GDP by county x industry, chained dollars")]:
        add("jobs", "bea_county_gdp", f"https://apps.bea.gov/regional/zip/{t}.zip", f"{t}.zip",
            snapshot=True, note=note + "; BEA revises every year")
    add("jobs", "bls_ind_occ_matrix", "https://www.bls.gov/emp/ind-occ-matrix/matrix.xlsx", "matrix.xlsx",
        snapshot=True, note="National employment matrix: jobs within each industry, 2025 + 2035 projected (US only)")
    for y in YEARS_OEWS_RESEARCH:
        add("jobs", "bls_oews_research", f"https://www.bls.gov/oes/special-requests/oes_research_{y}_allsectors.xlsx",
            f"oes_research_{y}_allsectors.xlsx", note=f"OEWS research estimates May {y}: state x industry x job (NY = 36)")
    for y in YEARS_QCEW_BLS:
        for fips in NYC_FIPS:
            add("jobs", "bls_qcew_county", f"https://data.bls.gov/cew/data/api/{y}/a/area/{fips}.csv",
                f"{y}_a_{fips}.csv", note=f"BLS QCEW {y} annual averages, county {fips}: ownership x NAICS (local government by industry)")

    # --- 2. Hiring, layoffs, licensing ---------------------------------------------------------
    qwi = "https://lehd.ces.census.gov/data/qwi/latest_release/ny/"
    for f in ["qwi_ny_sa_f_gc_ns_op_u.csv.gz", "qwi_ny_se_f_gc_ns_op_u.csv.gz",
              "qwi_ny.md5sum", "version_qwi.txt"]:
        add("hiring", "census_qwi", qwi + f, f, note="QWI hires/separations, county x NAICS sector x age (sa) or education (se)")
    add("hiring", "nysdol_ui_beneficiaries", socrata_export(SOCRATA_NY, "xbjp-8sra"), "xbjp-8sra.csv",
        note="UI beneficiaries by county, monthly since 2001")
    for year in range(1997, 2026):
        add("licensing", "nysed_registrants",
            f"{NYSED_OP}/about/registration-license-statistics/numbers-registered-licensees-{year}",
            f"numbers-registered-licensees-{year}.html", note="Registered licensees per profession, April 1")
    add("licensing", "nysed_license_stats_index", f"{NYSED_OP}/about/registration-license-statistics",
        "registration-license-statistics.html", snapshot=True, note="Index page; links to per-profession stats")
    for kind in ["rn", "pn"]:
        for span in NCLEX_SPANS:
            add("licensing", "nysed_nclex", NCLEX_PAGE.format(kind=kind, span=span),
                f"nclex-{kind}-{span}.html", note=f"{kind.upper()} NCLEX first-time pass rates by school")
    add("licensing", "nys_license_soc", socrata_export(SOCRATA_NY, "w2w4-tdxt"), "w2w4-tdxt.csv",
        note="NY license -> SOC crosswalk (has known errors, see report 02)")

    # --- 3. Graduates (supply) -----------------------------------------------------------------
    ipeds = "https://nces.ed.gov/ipeds/datacenter/data/"
    for y in YEARS_IPEDS:
        add("graduates", "ipeds_completions", f"{ipeds}C{y}_A.zip", f"C{y}_A.zip",
            note=f"Completions by college x CIP x award, academic year {y-1}-{str(y)[2:]}")
        add("graduates", "ipeds_directory", f"{ipeds}HD{y}.zip", f"HD{y}.zip", note="Institution directory")
    add("graduates", "ipeds_dictionary", f"{ipeds}C2024_A_Dict.zip", "C2024_A_Dict.zip")
    add("graduates", "nces_cip", "https://nces.ed.gov/ipeds/cipcode/Files/Crosswalk2010to2020.csv",
        "Crosswalk2010to2020.csv", note="CIP 2010 -> 2020 (IPEDS before C2020 uses CIP 2010)")
    add("graduates", "nces_cip", "https://nces.ed.gov/ipeds/cipcode/Files/CIPCode2020.csv", "CIPCode2020.csv")
    add("graduates", "nces_cip", "https://nces.ed.gov/ipeds/cipcode/Files/CIP2020_SOC2018_Crosswalk.xlsx",
        "CIP2020_SOC2018_Crosswalk.xlsx", note="Official major -> job crosswalk")
    add("graduates", "cuny_programs", socrata_export(SOCRATA_NY, "28gk-bu58"), "28gk-bu58.csv",
        note="CUNY graduates and fall enrollment by program, to AY 2024-25 / Fall 2025")
    add("graduates", "cuny_degrees_by_type", socrata_export(SOCRATA_NY, "ybg5-afvs"), "ybg5-afvs.csv",
        note="CUNY degrees granted by type (tie-out)")
    add("graduates", "cuny_enrollment", socrata_export(SOCRATA_NY, "487n-fp4r"), "487n-fp4r.csv",
        note="CUNY enrollment trends by college")

    # --- 4. Graduate outcomes and beginners ----------------------------------------------------
    pseo = "https://lehd.ces.census.gov/data/pseo/latest_release/ny/"
    add("outcomes", "census_pseo", pseo + "pseoe_ny.csv.gz", "pseoe_ny.csv.gz", note="Earnings by college x major")
    add("outcomes", "census_pseo", pseo + "pseof_ny.csv.gz", "pseof_ny.csv.gz", note="Where grads work (industry/region)")
    add("outcomes", "scorecard_fos",
        "https://ed-public-download.scorecard.network/downloads/Most-Recent-Cohorts-Field-of-Study_06102026.zip",
        "Most-Recent-Cohorts-Field-of-Study_06102026.zip", note="College Scorecard field of study")
    acs = "https://www2.census.gov/programs-surveys/acs/"
    add("outcomes", "acs_pums", acs + "data/pums/2024/5-Year/csv_pny.zip", "csv_pny_2020-2024_5yr.zip",
        note="ACS PUMS NY persons 2020-2024 (major x job x age x pay)")
    add("outcomes", "acs_pums", acs + "tech_docs/pums/data_dict/PUMS_Data_Dictionary_2020-2024.csv",
        "PUMS_Data_Dictionary_2020-2024.csv")
    add("outcomes", "acs_pums", acs + "tech_docs/code_lists/2024_ACS_Code_Lists.xlsx", "2024_ACS_Code_Lists.xlsx",
        note="Field-of-degree (FOD1P) code list")
    add("outcomes", "acs_pums",
        "https://www2.census.gov/programs-surveys/demo/guidance/industry-occupation/2018-occupation-code-list-and-crosswalk.xlsx",
        "2018-occupation-code-list-and-crosswalk.xlsx", note="Census OCCP -> SOC")
    add("outcomes", "acs_pums", "https://www2.census.gov/geo/docs/maps-data/data/rel2020/2020_Census_Tract_to_2020_PUMA.txt",
        "2020_Census_Tract_to_2020_PUMA.txt", note="Defines the 55 NYC PUMAs")
    # Published 2020-2024 5-year tables (all geographies, pipe-delimited), the tie-out for the PUMS file (nb 10)
    acs_sf = acs + "summary_file/2024/table-based-SF/data/5YRData/"
    for t, note in [("b01003", "Total population"), ("b15003", "Educational attainment, age 25+"),
                    ("b15012", "Bachelor's field of degree (first major), age 25+")]:
        add("outcomes", "acs_summary_tables", acs_sf + f"acsdt5y2024-{t}.dat", f"acsdt5y2024-{t}.dat",
            note=f"ACS 2020-2024 5-year published table: {note}")
    nyfed = "https://www.newyorkfed.org/medialibrary/research/interactives/data/college-labor-market/"
    add("outcomes", "nyfed_recent_grads", nyfed + "college-labor-outcomes-by-major-data.csv",
        "college-labor-outcomes-by-major-data.csv", snapshot=True, note="Unemployment/underemployment/wages by major (US)")
    add("outcomes", "nyfed_recent_grads", nyfed.replace("research/interactives/data", "Research/Interactives/Data")
        + "College-labor-data_historical.xlsx", "College-labor-data_historical.xlsx", snapshot=True)

    # --- 5. Pay ----------------------------------------------------------------------------------
    for y in OFLC_YEARS:
        add("pay", "dol_oflc_wages", f"https://flag.dol.gov/sites/default/files/wages/OFLC_Wages_{y}.zip",
            f"OFLC_Wages_{y}.zip", note=f"Prevailing wage Levels I-IV by SOC x area, July {y[:4]}")
    for fy in range(2019, 2026):  # one file per fiscal year (~550-610k rows each)
        add("pay", "nyc_payroll",
            socrata_query(SOCRATA_NYC, "k397-673e",
                          select="fiscal_year,agency_name,agency_start_date,work_location_borough,title_description,"
                                 "leave_status_as_of_june_30,base_salary,pay_basis,regular_hours,regular_gross_paid",
                          where=f"fiscal_year={fy}", order=":id"),
            f"k397-673e_fy{fy}_nonames.csv",
            note=f"NYC payroll FY{fy}; employee names deliberately NOT selected")

    # --- 6. Skills and postings --------------------------------------------------------------
    onet = "https://www.onetcenter.org/dl_files/database/"
    add("skills", "onet", onet + "db_31_0_csv.zip", "db_31_0_csv.zip", note="O*NET 31.0 (Aug 2026)")
    add("skills", "onet", onet + "db_30_0_text.zip", "db_30_0_text.zip", note="O*NET 30.0: last with Tools Used")
    add("skills", "onet", "https://www.onetcenter.org/taxonomy/2019/soc/2019_to_SOC_Crosswalk.xlsx?fmt=xlsx",
        "2019_to_SOC_Crosswalk.xlsx")
    add("skills", "onet", "https://www.onetcenter.org/crosswalks/cip/Education_CIP_to_ONET_SOC.xlsx",
        "Education_CIP_to_ONET_SOC.xlsx")
    cte = "https://careertech.org/wp-content/uploads/2025/09/"   # page: careertech.org/resource/framework-crosswalk/
    for f, note in [("Full_Framework_Crosswalk.xlsx", "Career Clusters: combined CIP-SOC-NAICS -> cluster/sub-cluster"),
                    ("Full_Framework_Crosswalk_CIP-Career-Clusters.xlsx", "Career Clusters: CIP -> cluster/sub-cluster"),
                    ("Full_Framework_Crosswalk_SOC-Career-Clusters.xlsx", "Career Clusters: SOC -> cluster/sub-cluster"),
                    ("Full_Framework_Crosswalk_NAICS-Career-Clusters-Subclusters.xlsx",
                     "Career Clusters: NAICS -> cluster/sub-cluster")]:
        add("skills", "career_clusters", cte + f, f, note=note + " (Advance CTE, modernized framework, Sep 2025 files)")
    gpt = "https://raw.githubusercontent.com/openai/GPTs-are-GPTs/0471612fef3cc22b74fb884d27bff9dbd3770582/"  # pinned commit, 2025-10-04
    for f, note in [("data/occ_level.csv", "AI exposure by O*NET-SOC job: GPT-4 (dv_) and human ratings; beta = E1 + 0.5*E2 (decision D7)"),
                    ("data/full_labelset.tsv", "AI exposure task labels (E0/E1/E2) per O*NET task, GPT-4 and human"),
                    ("README.md", "Repo README: column meanings"), ("LICENSE", "MIT license")]:
        add("skills", "eloundou_ai_exposure", gpt + f, f.split("/")[-1] if f != "LICENSE" else "LICENSE.txt",
            note="Eloundou et al. 2024 'GPTs are GPTs' (Science): " + note)
    aei = "https://huggingface.co/datasets/Anthropic/EconomicIndex/resolve/4e5f69fab13a9c3f7d0dcc31a6f893a9818738f6/"  # pinned, 2026-09-30
    for f, note in [("labor_market_impacts/job_exposure.csv", "observed exposure per SOC job (main AI score, decision D7 revised)"),
                    ("labor_market_impacts/task_penetration.csv", "share of each O*NET task seen in work-related Claude use"),
                    ("README.md", "dataset README (license: data CC-BY)")]:
        add("skills", "anthropic_ai_exposure", aei + f, f.split("/")[-1],
            note="Anthropic Economic Index, Massenkoff & McCrory (Mar 2026) 'Labor market impacts of AI': " + note)
    add("skills", "bls_ooh", "https://www.bls.gov/ooh/xml-compilation.xml", "xml-compilation.xml", snapshot=True,
        note="BLS Occupational Outlook Handbook, whole handbook as one XML (public domain): one-line description "
             "and SOC codes per profile (job page description; page: bls.gov/ooh/about/ooh-developer-info.htm)")
    # O*NET OnLine's per-job In Demand % (one CSV per O*NET-SOC code) is built by onet_in_demand(codes): the
    # code list comes from the job page's jobs, so notebook 16 makes the list and downloads it.
    add("postings", "nyc_jobs", socrata_export(SOCRATA_NYC, "kpav-sd4t"), "kpav-sd4t.csv",
        snapshot=True, note="NYC government postings; no history kept, so snapshot every run")
    add("postings", "nyc_civil_titles", socrata_export(SOCRATA_NYC, "nzjr-3966"), "nzjr-3966.csv",
        snapshot=True, note="DCAS civil service title codes")
    for f in ["aggregate_job_postings_US.csv", "state_job_postings_us.csv",
              "metro_job_postings_us.csv", "job_postings_by_sector_US.csv"]:
        add("postings", "indeed_hiring_lab", HIRING_LAB + f, f, snapshot=True,
            note="Indeed Hiring Lab postings index (CC BY 4.0), Feb 2020 = 100")
    rpls = "https://info0.s3.amazonaws.com/rpls/latest/postings/"   # page: reveliolabs.com/public-labor-statistics/job-openings
    for f, note in [("postings_by_sector_occupation_state.csv", "active postings by month x NAICS 2-digit x SOC 2-digit x state (decision D10)"),
                    ("postings_by_occupation.csv", "US active postings by month x SOC 2-digit"),
                    ("occupation_summary.csv", "US latest 3 months by SOC 2-digit")]:
        add("postings", "revelio_rpls", rpls + f, f, snapshot=True,
            note="Revelio Public Labor Statistics (free; 'latest' is overwritten monthly): " + note)

    # --- 7. BLS monthly time series (bulk flat files) ---------------------------------------------
    # The BLS API caps keyless use at a few requests/day per IP; these bulk files have the full history
    # and no cap. BLS revises them in place, so snapshot. Dots -> dashes so the date lands before .txt.
    for prefix, files, note in [
        ("jt", ["data.1.AllItems", "series", "state", "industry", "dataelement", "ratelevel",
                "sizeclass", "area", "period", "footnote", "txt"],
         "JOLTS openings/hires/quits/layoffs, US + states (NY state = 36), 2000-"),
        ("la", ["data.39.NewYork", "series", "area", "measure", "period", "footnote", "txt"],
         "LAUS unemployment, NY areas incl. the 5 borough counties, 1976-"),
        ("cu", ["data.1.AllItems", "series", "area", "item", "period", "footnote", "txt"],
         "CPI-U all items by area (NY-Newark-Jersey City = S12A), for real-dollar pay"),
    ]:
        for f in files:
            add("bls_timeseries", f"bls_{prefix}", f"https://download.bls.gov/pub/time.series/{prefix}/{prefix}.{f}",
                f"{prefix}-{f.replace('.', '-')}.txt", snapshot=True, note=note)
    return S


def onet_in_demand(codes: list[str]) -> list[dict]:
    """Registry entries for O*NET OnLine's "In Demand Technologies", two files per O*NET-SOC code (e.g. 13-2011.00).

    The CSV lists the software flagged In Demand for that job with "Percentage" = share of the job's U.S. job
    postings that mention it (Lightcast). Only the HTML page states the postings window, so it is kept too.
    Snapshot: O*NET refreshes the percentages in place. robots.txt allows /link/demand/ (checked);
    fetch() pauses between requests.
    """
    page = "https://www.onetonline.org/link/demand/{c}"
    S = []
    for c in codes:
        d = c.replace(".", "-")
        for url, ext, what in [(page.format(c=c) + f"/In_Demand_{d}.csv?fmt=csv", "csv", "CSV export"),
                               (page.format(c=c), "html", "page (states the Lightcast window)")]:
            S.append({"group": "skills", "key": "onet_in_demand", "url": url, "file": f"In_Demand_{d}.{ext}",
                      "snapshot": True, "note": f"O*NET OnLine In Demand Technologies (Lightcast postings %), {what}, job {c}"})
    return S


# The BLS series we'll read out of the bulk files above (exploration/staging filters on these IDs).
BLS_SERIES = {
    "cpi_ny_metro": ["CUURS12ASA0"],                       # CPI-U NY-Newark-Jersey City
    "jolts_ny": ["JTS000000360000000JOL", "JTS000000360000000HIL",   # openings, hires
                 "JTS000000360000000QUL", "JTS000000360000000LDL",   # quits, layoffs & discharges
                 "JTS000000360000000TSL"],                           # total separations
    "laus_nyc_counties": [f"LAUCN{f}0000000003" for f in NYC_FIPS],   # unemployment rate
}


# ---------------------------------------------------------------------------------------------
# Download helpers
# ---------------------------------------------------------------------------------------------
def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _record(row: dict) -> None:
    new = not MANIFEST.exists()
    with open(MANIFEST, "a", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_COLS)
        if new:
            w.writeheader()
        w.writerow({c: row.get(c, "") for c in MANIFEST_COLS})


def target_path(src: dict, today: str) -> Path:
    name = src["file"]
    if src.get("snapshot"):
        stem, dot, ext = name.partition(".")
        name = f"{stem}_{today}.{ext}" if dot else f"{name}_{today}"
    return RAW / src["group"] / src["key"] / name


def fetch(src: dict, today: str, session: requests.Session, pause: float = 1.0) -> dict:
    """Download one source unless it's already on disk. Returns a status row for the run log."""
    path = target_path(src, today)
    rel = path.relative_to(RAW).as_posix()
    if path.exists() and path.stat().st_size > 0:
        return {"file": rel, "status": "already have", "bytes": path.stat().st_size}
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".part")
    try:
        with session.get(src["url"], headers=HEADERS, stream=True, timeout=(30, 600)) as r:
            if r.status_code != 200:
                return {"file": rel, "status": f"HTTP {r.status_code}", "bytes": 0}
            with open(tmp, "wb") as fh:
                # raw stream: keep .gz/.zip bytes exactly as served, but let requests undo
                # transfer-level gzip on plain-text responses
                for chunk in r.iter_content(1 << 20):
                    fh.write(chunk)
        tmp.replace(path)
    except requests.RequestException as e:
        tmp.unlink(missing_ok=True)
        return {"file": rel, "status": f"error: {type(e).__name__}", "bytes": 0}
    size = path.stat().st_size
    _record({**src, "file": rel, "downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
             "bytes": size, "sha256": _sha256(path)})
    time.sleep(pause)
    return {"file": rel, "status": "downloaded", "bytes": size}

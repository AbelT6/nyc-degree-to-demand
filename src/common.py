"""Shared paths, code mappings and SOC helpers imported by the pipeline notebooks (notebooks/02-07)."""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
INTERIM = ROOT / "data" / "interim"
PROCESSED = ROOT / "data" / "processed"
SQL = ROOT / "sql"
DB = ROOT / "data" / "cuny_gap.duckdb"

CUNY_SYSTEM_NAME = "City University of New York"
CUNY_SYSTEM_OFFICE = 190035  # administrative unit, awards no degrees

# IPEDS AWLEVEL codes -> label and the level group used for matching to occupations.
# Totals (12, 13, 14, 15) are dropped; 1 is the pre-2020 "<1 year" code, kept for completeness.
AWLEVELS = {
    20: ("Certificate < 12 weeks", "sub_bacc"),
    21: ("Certificate 12 weeks - 1 year", "sub_bacc"),
    1: ("Certificate < 1 year", "sub_bacc"),
    2: ("Certificate 1-2 years", "sub_bacc"),
    3: ("Associate's degree", "sub_bacc"),
    4: ("Certificate 2-4 years", "sub_bacc"),
    5: ("Bachelor's degree", "bachelors"),
    6: ("Postbaccalaureate certificate", "bachelors"),
    7: ("Master's degree", "graduate"),
    8: ("Post-master's certificate", "graduate"),
    17: ("Doctor's - research/scholarship", "graduate"),
    18: ("Doctor's - professional practice", "graduate"),
    19: ("Doctor's - other", "graduate"),
}

# BLS "typical education needed for entry" -> occupation level group.
# Which completer groups may fill which occupation groups is set in sql/02_allocation.sql.
EDUCATION_GROUP = {
    "Doctoral or professional degree": "graduate",
    "Master's degree": "graduate",
    "Bachelor's degree": "bachelors",
    "Associate's degree": "sub_bacc",
    "Postsecondary nondegree award": "sub_bacc",
    "Some college, no degree": "sub_bacc",
    "High school diploma or equivalent": "hs_or_less",
    "No formal educational credential": "hs_or_less",
}


def log(step: str, before: int | None = None, after: int | None = None) -> None:
    """Print a row-count line so every filter is visible in the run output."""
    if before is None:
        print(f"  {step}")
    else:
        print(f"  {step}: {before:,} -> {after:,} rows ({after - before:+,})")


def soc_prefix(code: str) -> str:
    """SOC code with trailing zeros dropped: 15-1200 -> 15-12, 13-1020 -> 13-102.

    Any code that starts with this prefix sits under it in the SOC hierarchy.
    """
    major, rest = code.split("-")
    return f"{major}-{rest.rstrip('0')}"


def leaf_codes(codes: pd.Series) -> set[str]:
    """Codes with no more-detailed code beneath them in the same list."""
    codes = set(codes)
    leaves = set()
    for c in codes:
        p = soc_prefix(c)
        if not any(d != c and d.startswith(p) for d in codes):
            leaves.add(c)
    return leaves


# NY DOL (like BLS Employment Projections) publishes some "hybrid" codes that merge
# several SOC 2018 detailed codes. Other sources use the 2018 codes (or, in the CIP-SOC
# crosswalk, a few 2010-era codes), so they are translated to the hybrid code first.
HYBRID_SOC = {
    "11-9072": "11-9198", "11-9179": "11-9198", "11-9199": "11-9198",
    "13-2051": "13-2098", "13-2054": "13-2098", "13-2099": "13-2098",
    "15-1252": "15-1256", "15-1253": "15-1256",
    "15-1254": "15-1257", "15-1255": "15-1257",
    "19-3033": "19-3031", "19-3034": "19-3031",
    "21-1011": "21-1018", "21-1014": "21-1018",
    "25-2055": "25-2052", "25-2056": "25-2052",
    "25-3099": "25-3097",
    "25-9042": "25-9045", "25-9043": "25-9045", "25-9049": "25-9045",
    "29-1229": "29-1228", "29-1241": "29-1228",
    "29-1291": "29-1298", "29-1299": "29-1298",
    "39-1014": "39-1098", "39-1022": "39-1098",
    "39-4012": "39-9098", "39-9099": "39-9098",
    "51-2022": "51-2028", "51-2023": "51-2028",
    "53-1042": "53-1047", "53-1043": "53-1047", "53-1044": "53-1047", "53-1049": "53-1047",
    "53-3053": "53-3058", "53-3054": "53-3058",
}


def map_to_leaf(code: str, leaves: set[str]) -> str | None:
    """Map a SOC code to the NYC occupation grain: itself if it is a leaf, its hybrid
    code if one exists, else the nearest leaf ancestor (e.g. 13-1021 -> 13-1020)."""
    if HYBRID_SOC.get(code) in leaves:
        return HYBRID_SOC[code]
    if code in leaves:
        return code
    best = None
    for leaf in leaves:
        p = soc_prefix(leaf)
        if code.startswith(p) and (best is None or len(p) > len(soc_prefix(best))):
            best = leaf
    return best


def save(df: pd.DataFrame, name: str) -> None:
    PROCESSED.mkdir(parents=True, exist_ok=True)
    df.to_csv(PROCESSED / f"{name}.csv", index=False)
    print(f"  wrote data/processed/{name}.csv ({len(df):,} rows)")

"""Parsers for the job page's two text sources, shared by the notebooks that explore and load them.

- BLS Occupational Outlook Handbook XML (`bls_ooh`): one-line description per profile, its SOC codes, and the parts
  of the profile used to hand-check shared profiles (nb 15 §5). Card: docs/source-cards/bls_ooh.md.
- O*NET OnLine "In Demand Software Skills" (`onet_in_demand`): one CSV + one HTML page per O*NET-SOC code; only the
  page states the Lightcast postings window. Card: docs/source-cards/onet_in_demand.md.

Used by notebooks/15-profile-bls-ooh, 16-profile-onet-in-demand and 36-load-ooh-in-demand.
"""
import re
import xml.etree.ElementTree as ET
from html import unescape
from pathlib import Path

import pandas as pd


def clean(h: str | None) -> str:
    """HTML fragment -> plain text: tags out, entities decoded, non-breaking and repeated spaces collapsed,
    no space before punctuation (stripping a link tag leaves 'managers .')."""
    s = re.sub(r"\s+", " ", unescape(re.sub(r"<[^>]+>", " ", h or "")).replace("\xa0", " ")).strip()
    return re.sub(r"\s+([.,;:])", r"\1", s)


def first_sentence(s: str) -> str:
    """Up to the first full stop that follows a lower-case letter, digit or ')' and precedes a capital
    (so 'U.S.' and 'e.g.' don't end a sentence)."""
    m = re.search(r"^(.+?[a-z0-9)]\.)(?:\s+[A-Z]|$)", s)
    return m.group(1) if m else s


def sentences(s: str) -> list[str]:
    """Split a description into sentences with the same rule as first_sentence()."""
    return re.split(r"(?<=[a-z0-9)]\.)\s+(?=[A-Z])", s)


def parse_ooh(path: Path) -> dict[str, pd.DataFrame]:
    """The OOH XML as four tables: `profiles` (one row per profile), `socs` (profile x SOC code), `types` (the
    'types of' paragraphs in What They Do: a bold job name and the first sentence about it) and `table` (the
    Job Outlook projections table: BLS's title for each SOC code). Description text is cleaned with clean()."""
    root = ET.parse(path).getroot()
    prof, socs, types, table = [], [], [], []
    for o in root.findall("occupation"):
        code = o.findtext("occupation_code")
        cov = o.find("soc_coverage")
        codes = [s.text.strip() for s in cov.findall("soc_code")] if cov is not None else []
        prof.append({"ooh_code": code, "ooh_title": clean(o.findtext("title")), "description": clean(o.findtext("description")),
                     "description_raw": o.findtext("description"), "n_soc": len(codes), "publish_date": o.findtext("publish_date")})
        socs += [{"ooh_code": code, "soc_code": s} for s in codes]
        for p in re.findall(r"<p[^>]*>(.*?)</p>", o.find("what_they_do").findtext("section_body") or "", flags=re.S):
            m = re.match(r"\s*(?:<(?:strong|em|b|i)>\s*)+(.+?)(?:\s*</(?:strong|em|b|i)>)+(.*)", p, flags=re.S)
            if m:
                types.append({"ooh_code": code, "type_name": clean(m.group(1)),
                              "type_sentence": first_sentence(clean(f"{m.group(1)} {m.group(2)}"))})
        for t, s in re.findall(r"<th>.*?<strong>(.*?)</strong>.*?</th>\s*<td[^>]*>\s*(\d\d-\d{4})\s*</td>",
                               o.find("job_outlook").findtext("section_datatable") or "", flags=re.S):
            table.append({"ooh_code": code, "soc_code": s, "table_title": clean(t)})
    meta = {c.tag: (c.text or "").strip() for c in root if c.tag != "occupation"}
    return {"meta": meta, "profiles": pd.DataFrame(prof), "socs": pd.DataFrame(socs), "types": pd.DataFrame(types),
            "table": pd.DataFrame(table)}


def check_description_overrides(seed: pd.DataFrame, ooh: dict[str, pd.DataFrame]) -> pd.Series:
    """True per seed row when its text is BLS's own wording: blank for 'keep', a sentence of the job's profile
    description for 'profile_part', or one of that profile's 'types of' sentences for 'bls_type'."""
    prof = ooh["profiles"][["ooh_code", "description"]].rename(columns={"description": "ooh_description"})
    s = seed[["soc_code", "verdict", "description"]].merge(ooh["socs"], on="soc_code", how="left").merge(prof, on="ooh_code", how="left")
    assert len(s) == len(seed)
    typ = ooh["types"].groupby("ooh_code").type_sentence.apply(set)
    ok = [(v == "keep" and t == "") or
          (v == "profile_part" and isinstance(d, str) and t in sentences(d)) or
          (v == "bls_type" and t in typ.get(c, set()))
          for v, t, d, c in zip(s.verdict, s.description, s.ooh_description, s.ooh_code)]
    return pd.Series(ok, index=seed.index)


def page_text(path: Path) -> str:
    """An O*NET OnLine page as one line of plain text (scripts and styles dropped)."""
    t = re.sub(r"<script.*?</script>|<style.*?</style>", "", path.read_text(encoding="utf-8"), flags=re.S)
    return re.sub(r"\s+", " ", unescape(re.sub(r"<[^>]+>", " ", t)))


def parse_in_demand_page(path: Path) -> dict:
    """What an In Demand page states: its O*NET-SOC code and title, how many products it shows, and the source
    line (vendor, geography, postings window)."""
    h = page_text(path)
    m_code = re.search(r"In Demand Software Skills (\d\d-\d{4}\.\d\d) - (.+?) Save Table", h)
    m_n = re.search(r"(\d+) software skills? shown", h)
    m_w = re.search(r"Source: (Lightcast) external site job postings data for the (.+?) between (\w+ \d+, \d{4}) "
                    r"and (\w+ \d+, \d{4})\.", h)
    title = m_code and re.sub(r"( Bright Outlook)+$", "", m_code.group(2))   # O*NET's badge sits inside the title line
    return {"page_code": m_code and m_code.group(1), "page_title": title,
            "n_shown": m_n and int(m_n.group(1)), "vendor": m_w and m_w.group(1), "geography": m_w and m_w.group(2),
            "window_start": m_w and m_w.group(3), "window_end": m_w and m_w.group(4)}


def read_in_demand_csv(path: Path) -> pd.DataFrame:
    """One In Demand CSV as text columns plus `csv_order` (O*NET's row order, 1 = first). Header-only = no products."""
    t = pd.read_csv(path, dtype=str, keep_default_na=False)
    assert list(t.columns) == ["Percentage", "Software Skill", "Hot Technology"], (path.name, list(t.columns))
    return t.assign(csv_order=range(1, len(t) + 1))

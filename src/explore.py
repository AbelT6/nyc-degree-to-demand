"""Shared helpers for the core exploration notebooks (notebooks/4x-analyze-*).

Read-only access to the `core` schema as `pipeline_writer` (the same .env the loaders use).
Framework §1 rule 6: helpers used by more than one notebook live here, not copy-pasted.
"""
from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
import psycopg
from dotenv import dotenv_values

ROOT = next(p for p in [Path(__file__).resolve(), *Path(__file__).resolve().parents] if (p / "src" / "common.py").exists())
ENV = dotenv_values(ROOT / ".env")


def connect() -> psycopg.Connection:
    """Autocommit, read-only session on cuny_gap."""
    conn = psycopg.connect(
        host=ENV.get("PGHOST") or os.environ.get("PGHOST") or "localhost",
        port=int(ENV.get("PGPORT") or os.environ.get("PGPORT") or 5432),
        dbname="cuny_gap",
        user="pipeline_writer",
        password=ENV.get("PG_PIPELINE_PASSWORD") or os.environ["PG_PIPELINE_PASSWORD"],
        autocommit=True,
    )
    conn.execute("set default_transaction_read_only = on")
    conn.execute("set search_path = core, public")
    return conn


_CONN: psycopg.Connection | None = None


def q(sql: str, **params) -> pd.DataFrame:
    """Run a SELECT against core and return a DataFrame. Numeric columns come back as float."""
    global _CONN
    if _CONN is None or _CONN.closed:
        _CONN = connect()
    cur = _CONN.execute(sql, params or None)
    cols = [d.name for d in cur.description]
    df = pd.DataFrame(cur.fetchall(), columns=cols)
    for i in range(df.shape[1]):
        col = df.iloc[:, i]
        if col.dtype == object:
            sample = col.dropna()
            if len(sample) and all(type(v).__name__ == "Decimal" for v in sample.head(50)):
                df.isetitem(i, pd.to_numeric(col, errors="coerce"))
    return df


def pct(x: float, nd: int = 0) -> str:
    return f"{x * 100:+.{nd}f}%"

"""Load one cleaned DataFrame into the PostgreSQL `staging` schema, with the checks every load needs.

Used by notebooks/2x-load-*.ipynb. Each notebook reads data/raw/, applies its source card's
issues list (section 6) and calls `stage()` once per table in the card's section 7. `stage()`:

1. checks the declared key is unique and has no nulls, and the row count matches the card (brief S13);
2. saves a typed local copy to data/interim/staging/<table>.parquet (so the notebook runs before the DB exists);
3. if the database is reachable: (re)creates staging.<table> with explicit types, COPYs the rows in,
   adds the primary key, re-counts the rows in the database, and writes a table comment (source + notebook);
4. appends one line to data/interim/staging/_load_log.csv.

Connection settings come from the git-ignored .env at the project root: PG_PIPELINE_PASSWORD (required),
PGHOST and PGPORT (optional). No password is ever printed or written to a file.
"""
import os
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from common import INTERIM, ROOT

STAGE_DIR = INTERIM / "staging"
LOAD_LOG = STAGE_DIR / "_load_log.csv"
DBNAME, USER, SCHEMA = "cuny_gap", "pipeline_writer", "staging"


# --- connection ----------------------------------------------------------------------------------------
def connect():
    """psycopg connection as pipeline_writer, or None when the database isn't set up yet (prints why)."""
    try:
        import psycopg
        from dotenv import load_dotenv
    except ImportError as e:
        print(f"  DB skipped: {e.name} not installed")
        return None
    load_dotenv(ROOT / ".env")
    pw = os.environ.get("PG_PIPELINE_PASSWORD")
    if not pw:
        print("  DB skipped: PG_PIPELINE_PASSWORD not set in .env (database not set up yet)")
        return None
    try:
        # autocommit: each stage() call's `conn.transaction()` is then a real BEGIN/COMMIT. Without it, any other
        # query on this connection opens an outer transaction, later loads become savepoints inside it, and they
        # are silently rolled back on close (the in-DB row count still passes, since it runs inside the same one).
        return psycopg.connect(host=os.environ.get("PGHOST", "localhost"), port=os.environ.get("PGPORT", "5432"),
                               dbname=DBNAME, user=USER, password=pw, connect_timeout=5, autocommit=True)
    except psycopg.OperationalError as e:
        print(f"  DB skipped: cannot connect ({str(e).splitlines()[0]})")
        return None


# --- types ---------------------------------------------------------------------------------------------
def pg_type(s: pd.Series) -> str:
    """PostgreSQL type for a cleaned column. Notebooks cast first; this only reads the pandas dtype."""
    t = s.dtype
    if pd.api.types.is_bool_dtype(t):
        return "boolean"
    if pd.api.types.is_integer_dtype(t):
        return "bigint" if len(s.dropna()) and s.dropna().abs().max() > 2_000_000_000 else "integer"
    if pd.api.types.is_float_dtype(t):
        return "double precision"
    if pd.api.types.is_datetime64_any_dtype(t):
        return "date" if (s.dropna().dt.normalize() == s.dropna()).all() else "timestamp"
    if isinstance(t, pd.CategoricalDtype) or pd.api.types.is_string_dtype(t) or t == object:
        vals = s.dropna()
        if len(vals) and not vals.map(lambda v: isinstance(v, str)).all():
            bad = vals[~vals.map(lambda v: isinstance(v, str))].iloc[0]
            raise TypeError(f"column {s.name!r} mixes text with {type(bad).__name__} ({bad!r}); cast it first")
        return "text"
    raise TypeError(f"column {s.name!r}: no PostgreSQL type for dtype {t}")


# --- checks --------------------------------------------------------------------------------------------
def check(df: pd.DataFrame, table: str, key: list[str], expected_rows: int | None) -> None:
    """Fail loudly if the key isn't a key or the row count isn't the one the source card promised."""
    missing = [k for k in key if k not in df.columns]
    assert not missing, f"{table}: key columns not in the frame: {missing}"
    nulls = df[key].isna().sum()
    assert not nulls.any(), f"{table}: nulls in key columns: {nulls[nulls > 0].to_dict()}"
    dups = df.duplicated(key).sum()
    assert dups == 0, f"{table}: {dups:,} duplicate rows on key {key}"
    if expected_rows is not None:
        assert len(df) == expected_rows, f"{table}: {len(df):,} rows, source card expects {expected_rows:,}"
    assert all(c == c.lower() and " " not in c for c in df.columns), f"{table}: column names must be snake_case"


# --- the one call each notebook makes per table --------------------------------------------------------
def stage(df: pd.DataFrame, table: str, key: list[str], *, expected_rows: int | None, source_key: str,
          notebook: str, conn=None, comment: str = "") -> pd.DataFrame:
    """Check, save locally, and (if `conn`) load `df` into staging.<table>. Returns a one-row summary."""
    assert table.startswith("stg_"), "staging tables are named stg_<publisher>__<entity>"
    check(df, table, key, expected_rows)
    types = {c: pg_type(df[c]) for c in df.columns}

    STAGE_DIR.mkdir(parents=True, exist_ok=True)
    local = STAGE_DIR / f"{table}.parquet"
    df.to_parquet(local, index=False)

    in_db = None
    if conn is not None:
        in_db = _load_pg(conn, df, table, key, types,
                         f"{comment} Source: {source_key}. Loaded by {notebook}.".strip())
        assert in_db == len(df), f"{table}: {len(df):,} rows sent, {in_db:,} in the database"

    row = {"table": table, "rows": len(df), "cols": df.shape[1], "key": " + ".join(key),
           "source_key": source_key, "notebook": notebook, "in_db": in_db if in_db is not None else "not loaded",
           "loaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    pd.DataFrame([row]).to_csv(LOAD_LOG, mode="a", header=not LOAD_LOG.exists(), index=False)
    print(f"  {table}: {len(df):,} rows x {df.shape[1]} cols, key {key} unique | "
          f"local {local.relative_to(ROOT).as_posix()} | DB: {in_db if in_db is not None else 'not loaded'}")
    return pd.DataFrame([row])


def _load_pg(conn, df, table, key, types, comment) -> int:
    from psycopg import sql
    q = sql.Identifier(SCHEMA, table)
    cols = sql.SQL(", ").join(sql.SQL("{} {}").format(sql.Identifier(c), sql.SQL(t)) for c, t in types.items())
    with conn.transaction(), conn.cursor() as cur:
        cur.execute(sql.SQL("DROP TABLE IF EXISTS {}").format(q))
        cur.execute(sql.SQL("CREATE TABLE {} ({})").format(q, cols))
        names = sql.SQL(", ").join(map(sql.Identifier, df.columns))
        with cur.copy(sql.SQL("COPY {} ({}) FROM STDIN").format(q, names)) as cp:
            for rec in df.astype(object).where(df.notna(), None).itertuples(index=False, name=None):
                cp.write_row(rec)
        cur.execute(sql.SQL("ALTER TABLE {} ADD PRIMARY KEY ({})").format(q, sql.SQL(", ").join(map(sql.Identifier, key))))
        cur.execute(sql.SQL("COMMENT ON TABLE {} IS {}").format(q, sql.Literal(comment)))
        cur.execute(sql.SQL("SELECT count(*) FROM {}").format(q))
        return cur.fetchone()[0]


def raw_files(key: str) -> pd.DataFrame:
    """Manifest rows for one source key (latest snapshot last), with an absolute `path` column."""
    from common import RAW
    man = pd.read_csv(RAW / "manifest.csv", dtype=str, keep_default_na=False)
    man = man[man.key == key].copy()
    assert len(man), f"no files for source key {key!r} in the manifest"
    man["path"] = man.file.map(lambda f: RAW / f)
    missing = [str(p) for p in man.path if not Path(p).exists()]
    assert not missing, f"manifest lists files that aren't on disk: {missing}"
    return man.sort_values("downloaded_utc").reset_index(drop=True)

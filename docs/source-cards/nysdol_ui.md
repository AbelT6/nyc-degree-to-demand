# Source card: NYS DOL unemployment insurance beneficiaries

**Explored in:** profiled and loaded in `notebooks/35-load-nysdol-ui.ipynb` · Verdict: context: monthly regular-UI beneficiaries by county

## 1. What it is
- **Publisher / dataset:** NYS DOL, "Unemployment Insurance Beneficiaries and Benefit Amounts Paid: Beginning 2001" (data.ny.gov `xbjp-8sra`)
- **Files:** `hiring/nysdol_ui_beneficiaries/xbjp-8sra.csv` (downloaded 2026-10-12)
- **How it was collected:** administrative records of benefits paid
- **Covers:** regular UI only (UI, UCFE, UCX, Shared Work, SEAP); excludes federal extensions and 599.2 training. Pandemic programs not mentioned
- **License / terms:** none stated; attribution NYS DOL
- **Documentation:** [data.ny.gov dataset page](https://data.ny.gov/d/xbjp-8sra)

## 2. Shape
- **One row =** year × month × county; 64 areas (62 counties + out-of-state + unknown) × 308 months (Jan 2001 → Aug 2026) = 19,712, complete grid 
- **NYC slice:** region "New York City" = Bronx, Kings, New York, Queens, Richmond

## 3. Key columns
| Column | Meaning | Notes |
|---|---|---|
| `beneficiaries` | People receiving benefits that month | Rounded to 100 |
| `benefit_amount_usd` | Dollars paid | Rounded to $10,000 |

## 5. Tie-out
- No published total in the file. Checks: complete grid, every value a multiple of the stated rounding, each county in one region

## 6. Issues list
| # | Issue | Treatment |
|---|---|---|
| 1 | Rounding | Sum, then label as approximate |
| 2 | 2020 peak may miss pandemic programs | Label "regular UI only" |

## 7. Staging table
- `stg_nysdol__ui_beneficiaries`: key `year + month + county`; `region`, `is_nyc`, `beneficiaries`, `benefit_amount_usd`

# Docs

| Document | What it covers |
|---|---|
| [project-brief.md](project-brief.md) | The question, the users and the scope rules, written before any data work |
| [data-pipeline.md](data-pipeline.md) | How the data was collected, cleaned, loaded and tested, source by source, with row counts and tie-outs |
| [schema-design.md](schema-design.md) | The PostgreSQL design: `staging` → `core` (star schema) → `mart`, grains, keys and roles |
| [decisions.md](decisions.md) | The main judgment calls (data defects, code changes, the major → job link, uncertainty rules) and why |
| [framework.md](framework.md) | The working method for profiling, documenting and consolidating each source |
| [source-map.md](source-map.md) | Which source answers which question (bus matrix) |
| [source-cards/](source-cards/) | One card per source: publisher, grain, coverage, quirks, issues found and how they were handled |
| [screenshots/](screenshots/) | The report's pages |

These documents were written during the build and are kept as written, so each one has its own status line and date.

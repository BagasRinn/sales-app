# Sales Import Template v2 Implementation Progress

Source plan: [importsales.md](./importsales.md)

This file is the repository-visible progress tracker for future agents. Update
the status and evidence as each work item is completed. Existing worktree
changes were present before this implementation; preserve and integrate them.

## Status key

- `[ ]` Not started
- `[-]` In progress
- `[x]` Complete and verified
- `[!]` Blocked or requires external/manual validation

## Work items

- [x] **Schema and large-file foundation** — Idempotent columns and snapshot
  invalidation; upload streams to a temporary file; `.xlsx` parsing is
  read-only and writes are batched. Schema migration is also invoked by the
  integration-test setup when `TestClient` does not start app lifespan.
- [x] **Template v2 parsing and stable upsert** — Header aliases/detection,
  strict v2 branch/date/item validation, v2 natural keys, occurrence handling,
  mutable financial/dimension fields, and update timestamps. Parser/key/upsert
  tests pass.
- [x] **Permissions and monthly deletion** — Global-manager-only writes,
  supervisor/global-manager reads, idempotent locked month deletion, audit
  log, and version/summary updates. Focused integration tests pass.
- [x] **Margin, dimensions, and date-range API** — Margin/Devisi/Mother SKU
  aggregation, 1/3/6/12 month summaries, and combined range versions. Backend
  and UI model tests pass.
- [x] **Analytics UI** — Margin KPIs and toggles, period chips, read-only
  controls, deletion confirmation, and large-file feedback. Focused Flutter
  tests and `flutter analyze` pass.
- [x] **Automated tests** — Backend key/parser/range/upsert tests: 30 passed;
  import API integration suite: 39 passed in the full run, then all 6
  modified summary/permission/deletion integration tests passed. Focused
  Flutter tests: 11 passed.
- [!] **Docs and rollout QA** — Dedupe docs and Caddy upload limits/timeouts
  updated. Still requires validation with the original manager workbook,
  realistic 70 MB upload/12-month performance data, and deployment/staging
  configuration.

## Data Penjualan targets (`importtarget.md`)

- [x] **Storage and backend import** — Dedicated target table, header-driven
  multi-sheet parser, strict branch/period/value validation, upsert, and
  `SALES_TARGETS` audit log implemented.
- [x] **Summary and freshness** — Target aggregates are scoped by branch and
  period range; target timestamps are included in summary/version responses so
  clients refresh without rebuilding sales snapshots.
- [x] **Dashboard progress and upload UI** — Sales/Supplier rankings show
  omzet-based progress; MANAGER global can import target workbooks and review
  per-sheet results. Cache invalidation follows target changes. The ranking
  row keeps both bars: the omzet comparison is thicker and uses Deep
  Navy/slate ranking colors; target progress is thinner with a neutral track,
  status color, accessible percentage, and exact actual/target amounts.
- [x] **Tests and docs** — Added backend/API and Flutter coverage plus
  `docs/data-penjualan-target.md`. Target/import API and parser regression
  tests: 36 passed; focused Flutter tests: 18 passed; `flutter analyze` and
  Python compile check are clean.
- [!] **Rollout QA** — Still requires testing with the manager's real target
  workbook and a deployed database to confirm active branch labels and
  operational permissions.

## Important constraints

- Re-import is upsert-only; rows missing from an upload are not deleted.
- Keep historical template parsing and endpoint behavior compatible except for
  the explicitly approved permission restrictions.
- Changes already staged or unstaged before this task are not assumed to be
  disposable; review and integrate them rather than reverting them.
- Do not mark manual workbook/staging checks complete without performing them.
- Last target verification: backend target/import API and parser selection
  (36 passed), focused Flutter tests (18 passed), `flutter analyze` (clean),
  and Python compile check (clean).
- Last automated verification: backend parser/key/range/upsert (30 passed),
  API integration regression selection (6 passed), Flutter focused tests
  (11 passed), `flutter analyze` (clean), and Python compile check (clean).
  `ruff` was unavailable in the environment.

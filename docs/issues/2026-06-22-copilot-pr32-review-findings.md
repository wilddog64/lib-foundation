# Copilot review findings — PR #32 (v0.4.0 acg absorption)

**PR:** https://github.com/wilddog64/lib-foundation/pull/32
**Review:** `copilot-pull-request-reviewer[bot]`, 2026-06-23, state COMMENTED — 12 inline findings.
**Context:** PR #32 absorbs lib-acg into `scripts/lib/acg/` as a **verbatim clean tree-copy** from
lib-acg `7708ea31` (v0.1.9). The byte-for-byte fidelity of that copy was load-bearing — a prior
deviation (hoisting `bin/` to the repo root) regressed the live Playwright sandbox-delete flow.
Findings are therefore triaged by whether they touch **this PR's own new files** or **pre-existing
imported lib-acg code**.

---

## Fixed in this PR

| # | File:line | Finding | Fix |
|---|-----------|---------|-----|
| 5 | `Makefile:11` | `setup` help text says `npm install` | help text → `npm ci` (`f3f2fbd`) |
| 6 | `Makefile:25` | `setup` recipe `npm install` can drift from lockfile vs CI's `npm ci` | recipe → `npm ci` (`f3f2fbd`) |

The `Makefile` is a lib-foundation-authored delegating wrapper (not imported verbatim), so the
`npm ci` consistency fix is in scope and risk-free (dev-only target, not on the live credential path).

---

## Deferred — pre-existing imported lib-acg code (hardening backlog)

These are legitimate findings, but every one is **byte-identical to lib-acg `7708ea31`** and runs
in production today. Fixing them inside this absorption PR would (a) deviate from the verbatim import
the migration depends on, (b) mix hardening into an import PR, and (c) for the runtime browser/CDP
paths, cannot be live-validated right now (only the AWS credential path was exercised; GCP/Azure and
CDP-override paths were not). They are deferred to a dedicated **acg hardening pass** after the
absorption lands.

| # | File:line | Finding | Severity |
|---|-----------|---------|----------|
| 1 | `playwright/lib/output.js:27` | `writeFileSync(..., {mode:0o600})` does not reliably tighten perms on an existing creds file across platforms | med (secret hygiene) |
| 2 | `gcp.sh:104` | `source`s a creds file built from browser-extracted values — unescaped `$()`/backticks/newlines = shell injection (OWASP A03) | **high** |
| 3 | `vars.sh:6` | header comment references old lib-acg paths (`scripts/etc/...`, `scripts/plugins/...`) | low (stale comment) |
| 4 | `vars.sh:20` | comment points at `scripts/plugins/acg.sh`; constant now lives in `scripts/lib/acg/acg.sh` | low (stale comment) |
| 7 | `acg.sh:302` | CDP probe hard-codes `localhost:9222`, ignoring `_ACG_CHROME_CDP_PORT`/`PLAYWRIGHT_CDP_PORT` | med (config) |
| 8 | `cdp.sh:88` | `_browser_launch` hard-codes 9222 in probe, log, and Chrome launch args | med (config) |
| 9 | `cdp.sh:94` | `open -a "Google Chrome"` fallback hard-codes 9222 | med (config) |
| 10 | `playwright/acg_extend.js:99` | CDP URL hard-coded `localhost:9222`, ignores `PLAYWRIGHT_CDP_HOST/PORT` | med (config) |
| 11 | `playwright/acg_restart.js:9` | hard-codes CDP host/port instead of honoring env | med (config) |
| 12 | `acg_session_check.js:6` | CDP URL hard-coded `127.0.0.1:9222`, ignores `PLAYWRIGHT_CDP_HOST/PORT` | med (config) |

### Proposed hardening pass (follow-up, not this PR)

- **CDP port/host consistency (#7–#12):** thread `PLAYWRIGHT_CDP_HOST`/`PLAYWRIGHT_CDP_PORT` through
  every CDP entry point (`cdp.sh`, `acg.sh`, the three JS scripts) so overrides work uniformly.
  Requires a live CDP-override smoke test before merge.
- **gcp.sh creds injection (#2) + output.js perms (#1):** replace `source <credsfile>` with a safe
  key=value parser (no shell evaluation) and harden the creds-file write. Requires a live GCP
  sandbox to validate the GCP credential path.

---

## Process note

The verbatim-import principle and the "address Copilot findings" gate are in tension for an
absorption PR. Resolution: fix findings on **PR-authored files**, defer findings on **verbatim-imported
files** to a tracked hardening pass with live validation. This keeps the import faithful and avoids
re-regressing the live flow.

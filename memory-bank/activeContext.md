# Active Context — lib-foundation

## Current State: `feat/v0.4.2` (as of 2026-07-06)

**BUG #4 SPEC FILED (Claude, 2026-07-06) — credential-test still fails after BUG #3 because two gaps remain:** `docs/bugs/2026-07-06-credential-test-launch-and-browser-identity-guard.md`, branch `feat/v0.4.2`. **Diagnosed live this session:** even with `e136f55` in place, `make credential-test PROVIDER=aws` still dies at `connectOverCDP: … Browser context management is not supported`. Root cause is TWO gaps `e136f55` did not cover — (A) `_browser_launch` (cdp.sh:72–75) adopts ANY browser already on `:9222` without checking identity, so a stale system Chrome 150 squatting on the port (confirmed live: PID 56026 on old `--user-data-dir=…/k3d-manager/profile`, a pre-`e136f55` leftover) gets adopted → drift; (B) `bin/acg-credential-test` never calls `_browser_launch` at all — after `36c3bb1` it curl-guards `:9222` then only `_cdp_ensure_acg_session` (connect-only, never launches), so `e136f55`'s managed-Chromium launch is unreachable from this path. **Fix (2 files):** cdp.sh — hoist `_cdp_profile_dir`, guard the reuse branch with existing `_cdp_profile_in_use` so a foreign/stale browser is rejected with a clear `_err` instead of adopted; `bin/acg-credential-test` — replace the curl-guard + connect-only call with `_browser_launch` (self-launch + identity guard + gate), dropping the stale `open -a "Google Chrome"` guidance. **Verified before writing:** `_antigravity_browser_ready` (launch-branch dep) is defined in `scripts/lib/system.sh` and resolves when `cdp.sh` is sourced standalone (probe returned DEFINED). Commit message: `fix(acg): route credential-test through _browser_launch and guard CDP browser identity`. **NOT yet handed to Codex / not implemented.** **Immediate manual unblock offered to user (their live gate):** kill the stale PID 56026, launch managed Chromium on `:9222` via `require('playwright').chromium.executablePath()` into `pw-profile`, re-run. Relates to [[feedback_lib_acg_subtree_discipline]], [[feedback_lib_edits_upstream_first]].

**BUG #3 COMPLETE (Codex, 2026-07-06) — CDP now launches Playwright-managed Chromium, not system Chrome:** `docs/bugs/2026-07-06-cdp-use-playwright-managed-chromium.md`, branch `feat/v0.4.2`. **Root cause (diagnosed live this session):** `_browser_launch` (`scripts/lib/acg/cdp.sh`) launched system `/Applications/Google Chrome.app`; every ACG node script then `chromium.connectOverCDP`ed to it. System Chrome auto-updated independently and drifted past the pinned Playwright's DevTools-protocol support — observed Chrome 150 vs Playwright 1.60 (→ Chromium 148) failing `browserType.connectOverCDP: Protocol error (Browser.setDownloadBehavior): Browser context management is not supported`, dead-ending BOTH `make credential-test PROVIDER=aws` and the `make up` ACG path before the headless gate ran. **Empirically proven this session:** upgrading Playwright to 1.61.1 did NOT durably fix it (same failure — Chrome updates again); launching Playwright's own version-locked Chromium (`require('playwright').chromium.executablePath()` → `…/ms-playwright/chromium-1223/chrome-mac-arm64/Google Chrome for Testing.app/...`, confirmed EXISTS) and connecting over CDP returned `CONNECT_OK contexts=1`. **Implemented `e136f55ea39ea590c5ddccfa9fa4d064c42f4402`** (`fix(acg): launch Playwright-managed Chromium for CDP instead of system Chrome`), pushed to `origin/feat/v0.4.2`. Scope held exactly to the 3 listed files: `scripts/lib/acg/cdp.sh` now resolves the binary via `require('playwright').chromium.executablePath()` and hard-fails with an `npm install` message if absent (NO system-Chrome fallback), all 3 `cdp.sh` profile defaults now use `…/k3d-manager/pw-profile`, and `scripts/lib/acg/playwright/lib/output.js` `AUTH_DIR` now matches `pw-profile`. Gates passed: `shellcheck -S warning scripts/lib/acg/cdp.sh`, `npm run check`, `npm test`, sourcing probe `bash -c 'source scripts/lib/acg/cdp.sh; declare -f _browser_launch >/dev/null'`, and negative grep confirmed no `open -a "Google Chrome"` or `/Applications/Google Chrome.app` remained in `cdp.sh`. **USER acceptance gate (not Codex):** quit any stale system Chrome on `:9222`, then `make credential-test PROVIDER=aws` must launch Chrome-for-Testing, sign in headlessly, and extract creds before any subtree-pull. Relates to [[feedback_lib_acg_subtree_discipline]], [[feedback_lib_edits_upstream_first]], [[project_antigravity_migration]].

**v0.4.1 SHIPPED — PR #33 merged to main (`b7c849c`, 2026-07-06T02:56Z).** Headless Pluralsight auto-login + non-interactive fast-fail for unattended AWS-sandbox provisioning. Post-merge done: main synced, **TAGGED v0.4.1** (annotated tag at merge `b7c849c`; GitHub release published), `feat/v0.4.2` cut from the merge SHA, retro `docs/retro/2026-07-06-v0.4.1-retrospective.md` written, CHANGE.md `[Unreleased]` → `## [v0.4.1] — 2026-07-06`. No branch protection on main → no enforce_admins to restore. Standing docs current (change is JS-internal + a 9-line `cdp.sh` cred-load; no new public shell functions → `docs/api/functions.md` unaffected). Copilot round on PR #33: 4 findings, 3 fixed + 1 declined-with-evidence (`browser.close()` kept; `Browser.disconnect()` does not exist in Playwright 1.60.0) — triage `docs/issues/2026-07-05-copilot-pr33-review-findings.md`. **Downstream:** k3d-manager subtree-pull of v0.4.1 into `scripts/lib/foundation/` now unblocked (tag exists) — DONE (merge `67b466db`). **v0.4.2 BUG FILED (2026-07-06):** the v0.4.1 headless gate `_cdp_ensure_acg_session`→`acg_session_check.js`→`loginWithPage` shipped but is **never called** in any production path — `_browser_launch` only ensures CDP Chrome is up, not that Pluralsight is signed in. `make up`'s only sign-in (`sandbox.js:handleSignIn`) relies on Google Password Manager autofill, which can't fire in the `--password-store=basic` dedicated profile → no sign-in / no sandbox / no AWS env → CloudFormation `InvalidClientTokenId`. **Fix (spec `docs/bugs/2026-07-06-acg-session-gate-not-wired-into-browser-launch.md`):** call `_cdp_ensure_acg_session` on both `_browser_launch` paths; reuses tested v0.4.1 code, preserves fast-fail + `K3DM_ACG_SKIP_SESSION_CHECK` opt-out; no JS change. **IMPLEMENTED `96bea46`** (pushed `origin/feat/v0.4.2`; cdp.sh + acg_cdp.bats + CHANGE.md; shellcheck clean, 3 BATS cases). **v0.4.2 BUG #2 COMPLETE (Codex, 2026-07-06) — credential-test path now reuses the same gate and avoids the locked-profile fallback:** spec `docs/bugs/2026-07-06-acg-session-gate-not-wired-into-credential-test.md` implemented as commit **`36c3bb16ee832f09223693f59d25aa57c9ab0210`** (`fix(acg): wire _cdp_ensure_acg_session into acg-credential-test + guard connectBrowser CDP fallback`), pushed to `origin/feat/v0.4.2`. Scope held exactly to the 3 listed files: `scripts/lib/acg/bin/acg-credential-test` now sources `cdp.sh` and calls `_cdp_ensure_acg_session` after the CDP-alive check; `scripts/lib/acg/playwright/lib/browser.js` now throws a clear error instead of attempting `launchPersistentContext` when CDP is reachable but exposes no usable context; `CHANGE.md` `[Unreleased]` gained the required `### Fixed` entry. Required gates passed: `shellcheck -S warning scripts/lib/acg/bin/acg-credential-test`, `npm run check`, `npm test`, and the sourcing probe `bash -c 'source scripts/lib/acg/cdp.sh; declare -f _cdp_ensure_acg_session >/dev/null'` exited 0. **Acceptance gate remains user-run only:** `make credential-test PROVIDER=aws` in lib-foundation must be exercised by the operator before any subtree-pull or downstream claim. **Follow-up:** correct latent no-op `disconnect()` idiom in `gcp_login.js:157`.

## Current State: `feat/v0.4.1` (as of 2026-06-22)

**v0.4.0 SHIPPED — PR #32 merged to main (`aed8c56`, 2026-06-23T01:14Z).** lib-acg absorbed as optional module `scripts/lib/acg/` (9 commits, 44 files). Post-merge done: main fast-forwarded, `feat/v0.4.1` cut from merge SHA, retro `docs/retro/2026-06-22-v0.4.0-retrospective.md` written. **TAGGED v0.4.0** (`647408a` on feat/v0.4.1 split `[Unreleased]` → `## [v0.4.0]` + back-filled `## [v0.3.19]`; tag at merge `aed8c56`; GitHub release published). Drift resolved: tag v0.3.19 (`45040e2`) had been cut with no section; v0.3.18 + v0.3.20 never existed as tags. No branch protection on main → no enforce_admins to restore. Standing docs current (`copilot-instructions.md` has acg; acg API in `docs/api/acg.md`). **Next:** Phase 2 = rewire k3d-manager (scoping now); pre-existing `_sts_valid` bug + agy-cli/Antigravity CDP retarget tracked. History below.

**feat/v0.4.0 — Phase 1 follow-up + regression fix complete (`cf3ad7a`, 2026-06-22)** — absorb lib-acg into lib-foundation as optional module `scripts/lib/acg/`. REGRESSION FIX (`cf3ad7a`): `e6cecef`'s repo-root `bin/` hoist broke the live `make credential-test PROVIDER=aws` Playwright sandbox-delete flow ("Element is outside of the viewport"). A byte-for-byte lib-acg copy experiment isolated the cause — both layouts resolve `REPO_ROOT` to the same absolute path, so the only runtime difference is the **working directory at launch** (repo root vs `scripts/lib/acg`). Reverted: `bin/` is module-local again (`scripts/lib/acg/bin/`, `REPO_ROOT=".."`), Makefile `cd`s into the module first, CI shellcheck override dropped, `.gitignore` added (node_modules/, test-results/). **Live `make credential-test PROVIDER=aws` PASSED**; PR pending. Phase 0 done (lib-acg `v0.1.9` tagged; migration source SHA `7708ae31`). Decisions locked: v0.4.0 / clean tree-copy / `npm ci`. Spec: `docs/plans/v0.4.0-phase1-import-acg-module.md` (overview: `v0.4.0-absorb-lib-acg.md`). Phase 1 follow-up delivered: `scripts/lib/acg/playwright.config.js` imported, `bin/acg-credential-test` + `bin/acg-extend-test` moved to repo-root `bin/`, root `Makefile` added, `REPO_ROOT` repointed to `../scripts/lib/acg`, `acg` CI shellcheck path fixed, and docs/CHANGE updated. Validation passed (`npm ci`, `npm run check`, `npm test`, `shellcheck -S warning bin/acg-credential-test bin/acg-extend-test`, `make help`, `make lint`, `make test`, `git diff --check`). The first Playwright run hit a sandbox-only `EPERM` mkdir on `scripts/lib/acg/test-results`; the rerun with elevated access passed and is recorded in `docs/issues/2026-06-22-lib-foundation-playwright-test-results-permission.md`. Phase 2 = rewire k3d-manager; Phase 3 = archive lib-acg.

## Current State: `feat/v0.3.21` (as of 2026-05-30)

**v0.3.11 SHIPPED** — PR #17 merged to main (`2625683`) 2026-03-25. Tagged v0.3.11, GitHub release created. `enforce_admins` restored.
**v0.3.12 SHIPPED** — PR #18 squash-merged to main (`91340d62`) 2026-03-25. Tagged v0.3.12, GitHub release created. `enforce_admins` restored. Antigravity IDE install + Playwright MCP config helpers.
**v0.3.13 SHIPPED** — PR #19 squash-merged to main (`e870c6d9`) 2026-03-25. Tagged v0.3.13, GitHub release created. `enforce_admins` restored. Fix `_antigravity_browser_ready` curl probe (`_run_command --soft`).
**v0.3.14 SHIPPED** — PR #20 squash-merged to main (`bbbaf053`) 2026-03-27. Tagged v0.3.14, GitHub release created. `enforce_admins` restored. 5 deferred Copilot PR #51 findings: agy binary detection, curl fast-fail, NUL audit loops, doc fix, CHANGE.md versioning.
**v0.3.19 SHIPPED** — tag `45040e2` (2026-05-03). `_copilot_auth_check` rewrite (orig. planned as v0.3.18, never tagged) + `_copilot_review` --allow-all-tools/deny-tool fix. CHANGE.md section back-filled 2026-06-22 (`647408a`).
**PR #29 (sudo no-TTY fallback, `2f46d4be`, 2026-05-30)** — merged to main; NOT a v0.3.20 (no such tag). Folded into v0.4.0 CHANGE.md section.
**feat/v0.3.21 COMPLETE** — commit `f7a9178` merged and pushed to `origin/feat/v0.3.21`; `scripts/lib/core.sh` now consults optional `_cluster_provider_is_extra_supported` hooks in both provider validation case blocks, the contract BATS coverage was extended, and `CHANGE.md` records the change under `[Unreleased]`; next step is the k3d-manager consumer-side registration spec.

---

## Purpose

Shared Bash foundation library. Contains:
- `scripts/lib/core.sh` — cluster lifecycle, provider abstraction, `_resolve_script_dir`
- `scripts/lib/system.sh` — `_run_command`, `_run_command_resolve_sudo`, `_detect_platform`, package helpers, BATS install
- `scripts/lib/agent_rigor.sh` — `_agent_checkpoint`, `_agent_audit`, `_agent_lint`

Consumed by downstream repos via git subtree pull.
API reference: `docs/api/functions.md`

---

## Version Roadmap

| Version | Status | Notes |
|---|---|---|
| v0.1.0–v0.3.3 | released | See `docs/releases.md` |
| v0.3.4 | **SHIPPED** | PR #11 merged (`dbfafe9`) — doc fixes + upstream lib sync; tagged + released 2026-03-22 |
| v0.3.5 | **SHIPPED** | PR #10 merged (`2f895a99`) — doc-hygiene hook; 2026-03-23 |
| v0.3.6 | **SHIPPED** | PR #12 merged (`d8b4c48`) — code-fence exclusion + CoreDNS Check 4; 2026-03-23 |
| v0.3.7 | **SHIPPED** | PR #13 merged (`071c270`) — system.sh if-count cleanup; 2026-03-24; tagged v0.3.7 retroactively |
| v0.3.8 | **SHIPPED** | PR #14 merged (`a669a63`) — tab indentation enforcement in `_agent_audit`; 2026-03-24; tagged v0.3.8 retroactively |
| v0.3.9 | **SHIPPED** | PR #15 merged (`fb09921`) — release history backfill + memory-bank reconciliation; 2026-03-24; no tag (docs-only) |
| v0.3.10 | **SHIPPED** | PR #16 merged (`c5662c9`) — `.clinerules` fix; 2026-03-24; no tag (docs-only) |
| v0.3.11 | **SHIPPED** | PR #17 merged (`2625683`) — YAML IP check in `_agent_audit`; 2026-03-25; tagged v0.3.11 |
| v0.3.12 | **SHIPPED** | PR #18 merged (`91340d62`) — Antigravity IDE + MCP helpers; 7 BATS; 2026-03-25; tagged v0.3.12 |
| v0.3.13 | **SHIPPED** | PR #19 merged (`e870c6d9`) — `_antigravity_browser_ready` curl probe fix; 2026-03-25; tagged v0.3.13 |
| v0.3.14 | **SHIPPED** | PR #20 merged (`bbbaf053`) 2026-03-27 |
| v0.3.15–v0.3.17 | **SHIPPED** | PRs #21–#24 merged; v0.3.17 at `108924b9` 2026-05-01 |
| v0.3.18 | **IN PROGRESS** | branch `feat/v0.3.18`; PR #25 open |
| v0.3.20 | **SHIPPED** | PR #29 merged to main (`2f46d4be`) 2026-05-30; unreleased |

---

## v0.3.18 Open Items

- [x] **Bugfix: `_copilot_auth_check` K3DM_ENABLE_AI gate** — DONE (`f0e29d9`, `eede5c3`). Spec: `docs/plans/v0.3.18-bugfix-copilot-auth-preflight.md`. Removed `K3DM_ENABLE_AI` gate; checks env tokens → `~/.config/github-copilot/apps.json` → `gh auth status`; clear error on failure. New `scripts/tests/lib/copilot_auth.bats` (6 tests).
- [ ] **Copilot review non-interactive permissions** — OPEN. `docs/issues/2026-05-02-copilot-review-noninteractive-permissions.md`. `_copilot_review` still emits a non-interactive Copilot call without the CLI permission mode the help text describes as required.

---

## Pre-v0.3.18 Open Items

- [x] **PR #10 doc-hygiene hook** — staged-only `_agent_audit` BATS test added in commit `bdd60e7`; spec `docs/plans/v0.3.5-agent-audit-staged-only-test.md`. Branch: `feat/doc-hygiene-hook`.
- [x] **Doc hygiene staged-content read** — commit `d00bccb` implements `_dh_grep` index reader per `docs/plans/v0.3.5-doc-hygiene-staged-content-read.md`; branch pushed `feat/doc-hygiene-hook`.
- [x] **Doc hygiene staged-mode follow-ups** — commit `aeb1396` localizes `_DHC_STAGED`, gates staged file existence via `git cat-file`, and replaces staged-mode BATS per `docs/plans/v0.3.5-doc-hygiene-copilot-pr10-round2.md`.
- [ ] **k3d-manager subtree pull** — pull v0.3.5 into k3d-manager (PR #10 now merged)
- [x] **v0.3.6: Check 2 code-fence exclusion** — commit `7751068` adds `_dh_strip_fences`, optional `_dh_grep --strip-fences`, and 3 BATS tests per `docs/plans/v0.3.6-doc-hygiene-codefence-exclusion.md`.
- [x] **v0.3.6: CoreDNS Check 4** — commit `c352c1b` adds YAML-only warn on `<svc>.<ns>.svc(.cluster.local)` + 4 BATS tests per `docs/plans/v0.3.5-doc-hygiene-coredns-check.md`.
- [x] **v0.3.6: indented fence fix** — commit `02e7418` updates `_dh_strip_fences` to handle indented fences + adds indented BATS per `docs/plans/v0.3.6-doc-hygiene-indented-fence-fix.md`.
- [x] **v0.3.11: YAML hardcoded IP check** — commit `11e653b` adds staged `.yaml/.yml` IP detection to `_agent_audit` per `docs/plans/v0.3.11-agent-audit-yaml-ip-check.md`.
- [x] `rigor-cli` — repo bootstrapped (commit `a1c034f`), bash 3.2 fix (`8ae57bc`), gist installer (`310fd16`); lib-foundation spec: `docs/plans/v0.3.10-rigor-cli-init.md`; rigor-cli specs tracked in that repo (`plans/v0.1.1-mapfile-compat.md`, `plans/v0.1.1-gist-install-script.md`).
- [x] **v0.3.12: Antigravity helpers** — commit `ae0e8b9` adds `_ensure_antigravity_ide`, `_ensure_antigravity_mcp_playwright`, `_antigravity_browser_ready` per `docs/plans/v0.3.12-ensure-antigravity.md`.
- [x] **v0.3.13: antigravity browser probe fix** — commit `9350ecd` switches `_antigravity_browser_ready` to `_run_command --soft -- curl` per `docs/plans/v0.3.13-antigravity-browser-ready-fix.md`.
- [x] **v0.3.14: k3d-manager Copilot PR #51 deferred findings** — `e52b819` fixes all 5 upstream gaps per `docs/plans/v0.3.14-copilot-pr51-deferred-fixes.md`:
  - `_ensure_antigravity_ide` now detects `agy` binaries first
  - `_antigravity_browser_ready` fails fast when `curl` missing
  - `_agent_audit` tab scan iterates staged files via NUL-delimited loop
  - `docs/api/functions.md` explains `PLAYWRIGHT_MCP_VERSION` pinned MCP default
  - `CHANGE.md` versions the v0.3.12/v0.3.13 release notes
- [ ] `shopping-carts` as consumer (future)

---

## Key Contracts (must not change without coordinating all consumers)

- `_run_command [--prefer-sudo|--require-sudo|--interactive-sudo|--probe '<subcmd>'|--quiet|--soft] -- <cmd>`
- `_detect_platform` → `mac | wsl | debian | redhat | linux`
- `_cluster_provider` → `k3d | k3s | orbstack`
- `_resolve_script_dir` → absolute canonical path of calling script's real directory
- `_DCRS_PROVIDER` — global temp set by `_deploy_cluster_resolve_provider` (no command substitution — preserves TTY)
- `_RCRS_RUNNER` — global temp set by `_run_command_resolve_sudo`

---

## Consumers

| Repo | Integration | Status |
|---|---|---|
| `k3d-manager` | git subtree at `scripts/lib/foundation/` | subtree pull to v0.3.13 pending |
| `rigor-cli` | git subtree at `scripts/lib/foundation/` | subtree pull to v0.3.13 pending |
| `shopping-carts` | git subtree (planned) | future |

---

## Engineering Protocol

- **Tests**: always run with `env -i PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin" HOME="$HOME" TMPDIR="$TMPDIR" bash --norc --noprofile -c 'bats scripts/tests/lib/'`
- **shellcheck**: run on every touched `.sh` file before commit
- **No bare sudo**: always `_run_command --interactive-sudo` for install helpers, `--prefer-sudo` for non-interactive
- **All changes originate here** — never edit consumer subtree copies directly
- **Release flow**: PR → merge → tag → GitHub release → consumers run `git subtree pull`

## Lessons Learned

- `local -n` nameref requires bash 4.3+ — use global temp vars (`_RCRS_RUNNER`, `_DCRS_PROVIDER`) for output from helpers
- Command substitution `$()` creates a subshell — `[[ -t 0 && -t 1 ]]` is always false inside; use global temp vars instead
- `--prefer-sudo` silently drops to non-root when password sudo required — use `--interactive-sudo` for install helpers
- `git subtree add --squash` creates a merge commit that blocks GitHub rebase-merge — use squash-merge with admin override in consumers
- BATS must run with `env -i` — ambient `SCRIPT_DIR` causes false passes

# Active Context — lib-foundation

## Current State: `feat/v0.3.4` (as of 2026-03-16)

**v0.3.3 SHIPPED** — PR #8 squash-merged (b9f1fda), tagged, GitHub release created 2026-03-16.
**feat/v0.3.4 ACTIVE** — branch cut from main 2026-03-16. Spec written + pushed (`048040f`). Codex assigned to fix 12 doc accuracy issues.

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
| v0.3.4 | **active** | cut 2026-03-16 — no spec yet |

---

## Open Items

- [ ] **Fix `docs/api/functions.md`** — 12 Copilot findings from PR #8; spec at `docs/plans/v0.3.4-api-doc-fixes.md` (`048040f`). **Assigned to Codex 2026-03-22.** Exact old/new blocks in spec — docs-only, no `.sh` changes.
- [ ] **k3d-manager subtree pull** — pull v0.3.3 into k3d-manager (after v0.9.3 smoke test)
- [ ] `rigor-cli` — separate repo, lib-foundation as git subtree; CLI: `checkpoint|audit|lint`
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
| `k3d-manager` | git subtree at `scripts/lib/foundation/` | on v0.3.2; v0.3.3 pull pending |
| `rigor-cli` | git subtree (planned) | separate repo, future |
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

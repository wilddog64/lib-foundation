# Active Context — lib-foundation

## Current Branch: `extract/v0.1.0` (as of 2026-03-07)

**Status: PR #1 open — CI green, ready to merge → tag v0.1.0.**
- `core.sh` ✅ shellcheck passes
- `system.sh` ✅ shellcheck passes (SC2016 disable directives, quoting fixes, SC2155 splits)
- CI run: https://github.com/wilddog64/lib-foundation/actions/runs/22803721742 ✅

---

## Purpose

Shared Bash foundation library. Will contain:
- `scripts/lib/core.sh` — cluster lifecycle, provider abstraction
- `scripts/lib/system.sh` — `_run_command`, `_detect_platform`, package helpers, BATS install

Extracted from [`k3d-manager`](https://github.com/wilddog64/k3d-manager) via git subtree.
Re-integrated into consumers via git subtree pull.

---

## Current Focus

**No active Codex task on lib-foundation.** PR #1 is open, CI green, awaiting owner merge → tag v0.1.0.

**Branch protection:** `main` protected — required status checks `shellcheck` + `bats`, linear history, no force push.
**CI:** `.github/workflows/ci.yaml` — shellcheck + BATS 1.13.0 in `env -i` clean env.

---

## Consumers (planned)

| Repo | Integration | Status |
|---|---|---|
| `k3d-manager` | git subtree at `scripts/lib/foundation/` | pending extraction |
| `rigor-cli` | git subtree (planned) | future |
| `shopping-carts` | git subtree (planned) | future |

---

## Key Contracts

These function signatures must not change without coordinating across all consumers:

- `_run_command [--prefer-sudo|--require-sudo|--probe '<subcmd>'|--quiet] -- <cmd>`
- `_detect_platform` → `debian | rhel | arch | darwin | unknown`
- `_cluster_provider` → `k3d | k3s | orbstack`

---

## Open Items

- [x] Extract `core.sh` + `system.sh` into lib-foundation — ✅ done, PR #1 open, CI green
- [ ] BATS test suite for lib functions
- [ ] Add `rigor-cli` as consumer
- [ ] Add `shopping-carts` as consumer

---

## Engineering Protocol

- **Breaking changes**: coordinate across all consumers before merging to `main`
- **Tests**: always run with `env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/`
- **shellcheck**: run on every touched `.sh` file before commit
- **No bare sudo**: always `_run_command --prefer-sudo`

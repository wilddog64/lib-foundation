# Active Context — lib-foundation

## Current Branch: `extract/v0.1.0` (as of 2026-03-07)

**Status: Ready for extraction** — scaffold + CI + branch protection in place. `core.sh` and `system.sh` not yet extracted.

---

## Purpose

Shared Bash foundation library. Will contain:
- `scripts/lib/core.sh` — cluster lifecycle, provider abstraction
- `scripts/lib/system.sh` — `_run_command`, `_detect_platform`, package helpers, BATS install

Extracted from [`k3d-manager`](https://github.com/wilddog64/k3d-manager) via git subtree.
Re-integrated into consumers via git subtree pull.

---

## Current Focus

**Branch `extract/v0.1.0` cut from `main` — ready for Codex.**

Codex works on `extract/v0.1.0` in lib-foundation directly:
1. Clone `lib-foundation`, checkout `extract/v0.1.0`
2. Copy `core.sh` + `system.sh` from k3d-manager `scripts/lib/` → `scripts/lib/` here
3. Remove `.gitkeep` stubs
4. Run shellcheck, fix any issues
5. Commit + push
6. Claude opens PR `extract/v0.1.0 → main`, CI must pass, then merge → tag `v0.1.0`

In k3d-manager (separate Codex task):
- Update internal `source` references if paths change
- Add lib-foundation as git subtree remote for future pull/push

**Branch protection:** `main` protected — required status checks `shellcheck` + `bats`, linear history, no force push.
**CI:** `.github/workflows/ci.yaml` — shellcheck + BATS 1.13.0 in `env -i` clean env. Skips gracefully pre-extraction.

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

- [ ] git subtree extraction of `core.sh` + `system.sh` from k3d-manager (Codex — k3d-manager v0.6.5)
- [ ] BATS test suite for lib functions
- [ ] Add `rigor-cli` as consumer
- [ ] Add `shopping-carts` as consumer

---

## Engineering Protocol

- **Breaking changes**: coordinate across all consumers before merging to `main`
- **Tests**: always run with `env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/`
- **shellcheck**: run on every touched `.sh` file before commit
- **No bare sudo**: always `_run_command --prefer-sudo`

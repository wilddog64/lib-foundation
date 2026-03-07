# Active Context — lib-foundation

## Current Branch: `main` (as of 2026-03-07)

**Status: Scaffolded** — repo created, structure in place. `core.sh` and `system.sh` not yet extracted.

---

## Purpose

Shared Bash foundation library. Will contain:
- `scripts/lib/core.sh` — cluster lifecycle, provider abstraction
- `scripts/lib/system.sh` — `_run_command`, `_detect_platform`, package helpers, BATS install

Extracted from [`k3d-manager`](https://github.com/wilddog64/k3d-manager) via git subtree.
Re-integrated into consumers via git subtree pull.

---

## Current Focus

**Awaiting git subtree extraction from k3d-manager (Task 3 in v0.6.5)**

The extraction task (Codex) will:
1. `git subtree push` from k3d-manager → lib-foundation for `scripts/lib/core.sh` + `scripts/lib/system.sh`
2. Add lib-foundation as a git subtree remote in k3d-manager
3. Verify BATS tests still pass in both repos after extraction

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

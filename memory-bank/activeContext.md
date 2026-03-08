# Active Context — lib-foundation

## Current State: `main` (as of 2026-03-07)

**v0.1.1 SHIPPED** — PR #2 merged, tag `v0.1.1` local (push pending next release).
**No active branch** — next feature branch to be cut when next task is ready.

---

## Purpose

Shared Bash foundation library. Contains:
- `scripts/lib/core.sh` — cluster lifecycle, provider abstraction, `_resolve_script_dir`
- `scripts/lib/system.sh` — `_run_command`, `_detect_platform`, package helpers, BATS install

Consumed by downstream repos via git subtree pull.

---

## Version Roadmap

| Version | Status | Notes |
|---|---|---|
| v0.1.0 | released | `core.sh` + `system.sh` extraction, CI, branch protection |
| v0.1.1 | released | `_resolve_script_dir` — portable symlink-aware script locator |
| v0.1.2 | planned | TBD — awaiting next task |

---

## Key Contracts

These function signatures must not change without coordinating across all consumers:

- `_run_command [--prefer-sudo|--require-sudo|--probe '<subcmd>'|--quiet] -- <cmd>`
- `_detect_platform` → `mac | wsl | debian | redhat | linux`
- `_cluster_provider` → `k3d | k3s | orbstack`
- `_resolve_script_dir` → absolute canonical path of calling script's real directory (follows file symlinks)

---

## Consumers (planned)

| Repo | Integration | Status |
|---|---|---|
| `k3d-manager` | git subtree at `scripts/lib/foundation/` | **ACTIVE** — subtree pulled in v0.7.0 |
| `rigor-cli` | git subtree (planned) | future |
| `shopping-carts` | git subtree (planned) | future |

---

## Open Items

- [ ] Push tag `v0.1.1` to remote (on next release cycle)
- [ ] BATS test suite for lib functions (broader — future)
- [ ] Add `rigor-cli` as consumer
- [ ] Add `shopping-carts` as consumer
- [ ] **Sync deploy_cluster fixes from k3d-manager back into lib-foundation** — CLUSTER_NAME propagation + provider helper extraction (done in k3d-manager v0.7.0 local core.sh; not yet in lib-foundation core.sh). Consumers sourcing subtree directly get the old version until this is synced.
- [ ] **Remove duplicate mac+k3s guard in `deploy_cluster`** (`scripts/lib/core.sh` ~line 771 in k3d-manager subtree snapshot) — dead code, already removed from the subtree copy in k3d-manager v0.7.0 PR; apply same removal upstream here.
- [ ] **Route bare `sudo` in `_install_debian_helm` and `_install_debian_docker` through `_run_command`** — both functions use `sudo tee` and `sudo gpg` directly in piped commands, violating the no-bare-sudo contract. Refactor to use `_run_command --require-sudo`. Flagged by Copilot in k3d-manager PR #24.
- [ ] **Remote installer script integrity** — `_install_k3s`, `_install_istioctl`, `_install_bats_from_source`, and `_install_copilot_from_release` download and execute scripts without checksum or signature verification. Low priority for dev-only tooling; document as known dev-only pattern or add hash verification. Flagged by Copilot in k3d-manager PR #24.
- [ ] **Drop colima support** — delete `_install_colima` and `_install_mac_docker` from `scripts/lib/system.sh`. Update `_install_docker` mac case in `scripts/lib/core.sh` to print an OrbStack info message instead. OrbStack is the active macOS runtime; colima is untested and caused inotify issues. **Make these changes here in lib-foundation first** — k3d-manager will update its subtree via `git subtree pull --prefix=scripts/lib/foundation lib-foundation main --squash`. Do NOT wait for k3d-manager to push back.

---

## Engineering Protocol

- **Breaking changes**: coordinate across all consumers before merging to `main`
- **Tests**: always run with `env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/`
- **shellcheck**: run on every touched `.sh` file before commit
- **No bare sudo**: always `_run_command --prefer-sudo`
- **Branch protection**: 1 required review, dismiss stale, enforce_admins=false (owner can self-merge)

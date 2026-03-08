# Active Context — lib-foundation

## Current State: `feat/agent-rigor-v0.2.0` (as of 2026-03-08)

**v0.1.2 SHIPPED** — PR #3 merged, tag `v0.1.2` pushed. Colima support dropped.
**v0.2.0 active** — branch `feat/agent-rigor-v0.2.0` cut from main.

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
| v0.1.2 | released | Drop colima support (PR #3) |
| v0.2.0 | **active** | `agent_rigor.sh` — `_agent_checkpoint`, `_agent_audit`, `_agent_lint` |

---

## v0.2.0 — Completion Report (Codex)

Files created: `scripts/lib/agent_rigor.sh`; `scripts/hooks/pre-commit`; `scripts/etc/agent/lint-rules.md`; `scripts/tests/lib/agent_rigor.bats`
Shellcheck: PASS
BATS: 12/12 passing
`_agent_checkpoint`: DONE — repo_root via `git rev-parse --show-toplevel` (line 10)
`_agent_audit`: DONE — kubectl exec credential check removed; retains BATS/if-count/bare-sudo scans (lines 40–118)
`_agent_lint`: DONE — gated via `AGENT_LINT_GATE_VAR` + `AGENT_LINT_AI_FUNC` indirection (lines 121–158)
pre-commit template: DONE — sources `system.sh` + `agent_rigor.sh`, runs `_agent_audit` + optional `_agent_lint`
lint-rules.md: DONE — 5 rules ported from k3d-manager
BATS coverage: 10 targeted tests — `_agent_checkpoint` 3, `_agent_audit` 7 (12 total including existing `_resolve_script_dir` cases)
Unexpected findings: NONE

**Bug fix (staged diff):** `_agent_audit` git diff calls corrected to `--cached` (lines 48, 65, 105); 6 BATS tests updated to `git add` before audit call.
Status: **COMPLETE — ready for PR**

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

- [ ] BATS test suite for lib functions (broader — future)
- [ ] Add `rigor-cli` as consumer
- [ ] Add `shopping-carts` as consumer
- [ ] **Sync deploy_cluster fixes from k3d-manager back into lib-foundation** — CLUSTER_NAME propagation + provider helper extraction (done in k3d-manager v0.7.0 local core.sh; not yet in lib-foundation core.sh).
- [ ] **Remove duplicate mac+k3s guard in `deploy_cluster`** — dead code, already removed from subtree copy in k3d-manager v0.7.0 PR; apply same removal upstream here.
- [ ] **Route bare `sudo` in `_install_debian_helm` and `_install_debian_docker` through `_run_command`** — flagged by Copilot in k3d-manager PR #24.
- [ ] **Remote installer script integrity** — `_install_k3s`, `_install_istioctl`, `_install_bats_from_source`, `_install_copilot_from_release` download and execute without checksum verification. Low priority for dev-only tooling.

---

## Release Protocol (Option A — Independent Versioning)

lib-foundation uses independent semver (`v0.1.x`) separate from k3d-manager.

**Normal release flow (changes originate in k3d-manager):**

1. Codex edits both local k3d-manager copies and `scripts/lib/foundation/` subtree copies.
2. k3d-manager PR merges.
3. Claude applies the same changes directly to the lib-foundation local clone, opens a PR here, and merges.
   - `git subtree push` does NOT work — branch protection requires PRs; direct push is rejected.
4. Claude updates `CHANGE.md` here and cuts a new version tag (e.g. `v0.1.2`).
5. Claude runs `git subtree pull` in k3d-manager to sync the merged changes back into the subtree copy.
6. k3d-manager `CHANGE.md` records `lib-foundation @ v0.1.2`.

**Independent release flow (changes originate here):**

1. Changes made directly in lib-foundation, PR merged, tag cut.
2. Each consumer runs `git subtree pull --prefix=<path> lib-foundation <tag> --squash` to upgrade.

**Version tag convention:** `vMAJOR.MINOR.PATCH` — bump PATCH for fixes, MINOR for new functions, MAJOR for breaking contract changes.

**Breaking changes** require coordinating all consumers before merging to `main`.

---

## Engineering Protocol

- **Breaking changes**: coordinate across all consumers before merging to `main`
- **Tests**: always run with `env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/`
- **shellcheck**: run on every touched `.sh` file before commit
- **No bare sudo**: always `_run_command --prefer-sudo`
- **Branch protection**: 1 required review, dismiss stale, enforce_admins=false (owner can self-merge)

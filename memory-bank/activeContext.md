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

## v0.2.0 — Codex Task: Implement agent_rigor.sh

**Status: active — ready for Codex**

Full spec: `docs/plans/v0.2.0-agent-rigor-spec.md` — read it completely before writing any code.

### Your task

Create exactly 4 new files — nothing else:

1. `scripts/lib/agent_rigor.sh`
   - `_agent_checkpoint` — port from k3d-manager; replace `_k3dm_repo_root` with `git rev-parse --show-toplevel`
   - `_agent_audit` — port verbatim; remove kubectl exec credential check (Kubernetes-specific)
   - `_agent_lint` — generic redesign; gate via `AGENT_LINT_GATE_VAR` + AI wrapper via `AGENT_LINT_AI_FUNC`

2. `scripts/hooks/pre-commit` — hook template (see spec for exact content)

3. `scripts/etc/agent/lint-rules.md` — port 5 rules from k3d-manager (`scripts/etc/agent/lint-rules.md`)

4. `scripts/tests/lib/agent_rigor.bats`
   - `setup()` creates a temp git repo via `mktemp -d`; `teardown()` removes it
   - Unit tests for `_agent_checkpoint` (3 cases) and `_agent_audit` (7 cases)
   - Do NOT test `_agent_lint` — consumer responsibility

### Rules

- Edit only the 4 files listed above — do NOT touch `core.sh`, `system.sh`, or any existing file
- `shellcheck scripts/lib/agent_rigor.sh` must exit 0
- `env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/` must pass all suites
- bash 3.2+ compatible — no `declare -A`, no `mapfile`; `${!gate_var}` indirect expansion is allowed
- Do NOT run `git rebase`, `git reset --hard`, or `git push --force`
- Commit locally — Claude handles push and PR

### Required Completion Report

Update `memory-bank/activeContext.md` with:

```
## v0.2.0 Completion Report (Codex)

Files created: [list all 4]
Shellcheck: PASS / [issues]
BATS: N/N passing
_agent_checkpoint: DONE — repo_root via git rev-parse (line N)
_agent_audit: DONE — kubectl exec check removed (confirmed)
_agent_lint: DONE — AGENT_LINT_GATE_VAR + AGENT_LINT_AI_FUNC (lines N-N)
pre-commit template: DONE
lint-rules.md: DONE — N rules ported
BATS coverage: N tests — _agent_checkpoint N, _agent_audit N
Unexpected findings: NONE / [describe]
Status: COMPLETE / BLOCKED
```

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
- [ ] **Drop colima support** — delete `_install_colima` and `_install_mac_docker` from `scripts/lib/system.sh`. Update `_install_docker` mac case in `scripts/lib/core.sh` to print an OrbStack info message instead. Changes made by Codex in k3d-manager (both local + subtree copies); Claude pushes back here via `git subtree push`. Target: lib-foundation `v0.1.2`.

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

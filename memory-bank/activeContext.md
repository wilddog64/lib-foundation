# Active Context — lib-foundation

## Current Branch: `feature/v0.1.1-script-dir-resolver` (as of 2026-03-07)

**v0.1.0 SHIPPED** — PR #1 merged, tag `v0.1.0` pushed.
**v0.1.1 ready for PR** — Codex task complete, pushed to remote. Awaiting owner PR + merge → tag `v0.1.1`.

---

## Purpose

Shared Bash foundation library. Contains:
- `scripts/lib/core.sh` — cluster lifecycle, provider abstraction
- `scripts/lib/system.sh` — `_run_command`, `_detect_platform`, package helpers, BATS install

Consumed by downstream repos via git subtree pull.

---

## Current Focus

**v0.1.1: Add `_resolve_script_dir` — portable symlink-aware script location resolver**

### Background

Personal scripts in `~/.zsh/scripts/` are symlinked to `~/.local/bin/` and `~/.git-hooks/`.
When invoked via symlink, `${BASH_SOURCE[0]}` points to the symlink, not the real file.
Scripts need to resolve their own canonical directory to source siblings reliably.

`readlink -f` is not available on macOS stock — portable solution uses `pwd -P` (bash built-in, bash 3.2+, no external dependency).

### Codex Task: Add `_resolve_script_dir` to `scripts/lib/core.sh`

**Rules:**
1. Add only `_resolve_script_dir` to `scripts/lib/core.sh` — nothing else.
2. Run `shellcheck scripts/lib/core.sh` — must pass with exit 0.
3. Add a BATS test in `scripts/tests/lib/core.bats` (create if not exists):
   - Test that `_resolve_script_dir` returns an absolute path
   - Test that path is correct when called from a symlinked script in `$BATS_TEST_TMPDIR`
4. Commit own work locally — Claude pushes.
5. Update memory-bank to report completion.

**Implementation:**
```bash
# Resolve the canonical directory of the calling script, following symlinks.
# Uses pwd -P (POSIX, bash 3.2+) — works on macOS without GNU coreutils.
#
# Usage (in any script):
#   SCRIPT_DIR="$(_resolve_script_dir)"
_resolve_script_dir() {
  local src="${BASH_SOURCE[1]}"
  local dir
  dir="$(cd "$(dirname "$src")" && pwd -P)"
  echo "$dir"
}
```

**Note:** Global pre-commit hook (`~/.zsh/scripts/git-hooks/pre-commit`) should inline
`pwd -P` directly — must not depend on sourcing lib-foundation from outside a consumer repo.
Per-repo hooks can source from the subtree and call `_resolve_script_dir`.

---

## Version Roadmap

| Version | Status | Notes |
|---|---|---|
| v0.1.0 | released | `core.sh` + `system.sh` extraction, CI, branch protection |
| v0.1.1 | **active** | `_resolve_script_dir` helper |

---

## Consumers (planned)

| Repo | Integration | Status |
|---|---|---|
| `k3d-manager` | git subtree at `scripts/lib/foundation/` | pending subtree pull |
| `rigor-cli` | git subtree (planned) | future |
| `shopping-carts` | git subtree (planned) | future |

---

## Key Contracts

- `_run_command [--prefer-sudo|--require-sudo|--probe '<subcmd>'|--quiet] -- <cmd>`
- `_detect_platform` → `debian | rhel | arch | darwin | unknown`
- `_cluster_provider` → `k3d | k3s | orbstack`
- `_resolve_script_dir` → absolute canonical path of calling script's directory *(new in v0.1.1)*

---

## Open Items

- [x] Codex: implement `_resolve_script_dir` + BATS test (this branch)
- [ ] BATS test suite for lib functions (broader — future)
- [ ] Add `rigor-cli` as consumer
- [ ] Add `shopping-carts` as consumer

### Latest Update (2026-03-07 — Codex)

- Task: `_resolve_script_dir` helper + BATS coverage
- Status: COMPLETE
- Files changed: `scripts/tests/lib/core.bats`
- Shellcheck: PASS (`scripts/lib/core.sh`)
- BATS: PASS (`env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/core.bats`)
- Notes: `_make_test_script` now injects the resolved `CORE_LIB` path directly, keeping the helper tests hermetic without Perl substitutions.

---

## Engineering Protocol

- **Breaking changes**: coordinate across all consumers before merging to `main`
- **Tests**: always run with `env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/`
- **shellcheck**: run on every touched `.sh` file before commit
- **No bare sudo**: always `_run_command --prefer-sudo`

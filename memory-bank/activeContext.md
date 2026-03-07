# Active Context — lib-foundation

## Current Branch: `feature/v0.1.1-script-dir-resolver` (as of 2026-03-07)

**PR #1 (`extract/v0.1.0`) still open — owner must merge + tag v0.1.0 before this branch targets main.**

---

## Purpose

Shared Bash foundation library. Contains:
- `scripts/lib/core.sh` — cluster lifecycle, provider abstraction
- `scripts/lib/system.sh` — `_run_command`, `_detect_platform`, package helpers, BATS install

Extracted from [`k3d-manager`](https://github.com/wilddog64/k3d-manager).
Consumed by downstream repos via git subtree pull.

---

## Current Focus

**v0.1.1: Add `_resolve_script_dir` — portable symlink-aware script location resolver**

### Background

Personal scripts in `~/.zsh/scripts/` are symlinked to `~/.local/bin/` and `~/.git-hooks/`.
When invoked via symlink, `${BASH_SOURCE[0]}` points to the symlink, not the real file.
Scripts need to resolve their own canonical directory to source siblings reliably.

`readlink -f` is not available on macOS stock (`/usr/bin/readlink` lacks `-f`).
The portable solution uses `pwd -P` — bash built-in, no external dependency, bash 3.2+ compatible.

### Task: Add `_resolve_script_dir` to `scripts/lib/core.sh`

**Branch:** `feature/v0.1.1-script-dir-resolver`
**Target:** merge to `main` after PR #1 is merged (base will rebase onto main)

#### Implementation (add to `scripts/lib/core.sh`):

```bash
# Resolve the canonical directory of the calling script, following symlinks.
# Uses pwd -P (POSIX, bash 3.2+) — works on macOS without GNU coreutils.
#
# Usage (in any script):
#   SCRIPT_DIR="$(_resolve_script_dir)"
#
# Returns the real directory, not the symlink location.
_resolve_script_dir() {
  local src="${BASH_SOURCE[1]}"
  local dir
  dir="$(cd "$(dirname "$src")" && pwd -P)"
  echo "$dir"
}
```

#### Usage pattern (for consumer scripts):

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(_resolve_script_dir)"
source "$SCRIPT_DIR/../lib/core.sh"
```

#### Rules:
1. Add only `_resolve_script_dir` to `scripts/lib/core.sh` — nothing else.
2. Run `shellcheck scripts/lib/core.sh` — must pass.
3. Add a BATS test in `scripts/tests/lib/core.bats` (create if not exists):
   - Test that `_resolve_script_dir` returns an absolute path
   - Test that it resolves correctly when called from a symlinked script
4. Commit own work. Local commit is sufficient — Claude pushes.
5. Update memory-bank to report completion.

#### Note on global pre-commit hook:
The global hook (`~/.zsh/scripts/git-hooks/pre-commit`) should inline the
`pwd -P` pattern directly — it must not depend on sourcing lib-foundation,
since it runs outside any consumer repo context.
Per-repo hooks (e.g. `k3d-manager/scripts/hooks/pre-commit`) can source
lib-foundation's subtree copy and call `_resolve_script_dir`.

---

## Version Roadmap

| Version | Branch | Status | Notes |
|---|---|---|---|
| v0.1.0 | `extract/v0.1.0` | PR #1 open, CI green | `core.sh` + `system.sh` extraction |
| v0.1.1 | `feature/v0.1.1-script-dir-resolver` | **active** | `_resolve_script_dir` helper |

---

## Consumers (planned)

| Repo | Integration | Status |
|---|---|---|
| `k3d-manager` | git subtree at `scripts/lib/foundation/` | pending PR #1 merge |
| `rigor-cli` | git subtree (planned) | future |
| `shopping-carts` | git subtree (planned) | future |

---

## Key Contracts

These function signatures must not change without coordinating across all consumers:

- `_run_command [--prefer-sudo|--require-sudo|--probe '<subcmd>'|--quiet] -- <cmd>`
- `_detect_platform` → `debian | rhel | arch | darwin | unknown`
- `_cluster_provider` → `k3d | k3s | orbstack`
- `_resolve_script_dir` → absolute canonical path of calling script's directory *(new in v0.1.1)*

---

## Open Items

- [ ] Owner: merge PR #1 → tag `v0.1.0`
- [ ] Codex: implement `_resolve_script_dir` in `core.sh` + BATS test (this branch)
- [ ] BATS test suite for lib functions (broader — future)
- [ ] Add `rigor-cli` as consumer
- [ ] Add `shopping-carts` as consumer

---

## Engineering Protocol

- **Breaking changes**: coordinate across all consumers before merging to `main`
- **Tests**: always run with `env -i HOME="$HOME" PATH="$PATH" bats scripts/tests/lib/`
- **shellcheck**: run on every touched `.sh` file before commit
- **No bare sudo**: always `_run_command --prefer-sudo`

# Progress — lib-foundation

## Overall Status

**Scaffolded** — repo created 2026-03-07. Content not yet extracted.

---

## What Is Complete

- [x] GitHub repo created: `wilddog64/lib-foundation`
- [x] Directory structure: `scripts/lib/`, `scripts/tests/lib/`, `memory-bank/`
- [x] `CLAUDE.md` — navigation + key contracts + testing rules
- [x] `.clinerules` — Cline-compatible agent instructions
- [x] `memory-bank/` — context carried over from k3d-manager v0.6.5

---

## What Is Pending

- [ ] `git subtree push` from k3d-manager — extract `core.sh` + `system.sh` (Codex, k3d-manager v0.6.5)
- [ ] Integrate lib-foundation as subtree remote back into k3d-manager
- [ ] BATS test suite for lib functions
- [ ] Consumer integration: `rigor-cli`
- [ ] Consumer integration: `shopping-carts`

---

## Known Constraints

| Item | Notes |
|---|---|
| `SCRIPT_DIR` dependency | `system.sh` sources `agent_rigor.sh` via `$SCRIPT_DIR` at load time — must resolve correctly in subtree layout |
| Contract stability | `_run_command`, `_detect_platform`, `_cluster_provider` — signature changes require all-consumer coordination |
| Clean env testing | BATS must run with `env -i` — ambient `SCRIPT_DIR` causes false passes |

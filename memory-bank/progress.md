# Progress — lib-foundation

## Overall Status

**Active** — v0.1.0 shipped; v0.1.1 adds `_resolve_script_dir` helper.

---

## What Is Complete

- [x] GitHub repo created: `wilddog64/lib-foundation`
- [x] Directory structure: `scripts/lib/`, `scripts/tests/lib/`, `memory-bank/`
- [x] `CLAUDE.md` — navigation + key contracts + testing rules
- [x] `.clinerules` — Cline-compatible agent instructions
- [x] `memory-bank/` — context carried over from k3d-manager v0.6.5
- [x] Branch protection — `required_linear_history`, no force push, required status checks (`shellcheck`, `bats`)
- [x] CI — `.github/workflows/ci.yaml` — shellcheck + BATS 1.13.0, pre-extraction graceful skip, `env -i` clean env. ✅ green
- [x] `scripts/lib/core.sh` + `scripts/lib/system.sh` imported from k3d-manager (Codex) — shellcheck run; BATS suite empty (1..0)
- [x] `system.sh` shellcheck cleanup — SC2016 annotations, quoting fixes, and `_detect_cluster_name` locals (Codex)
- [x] `_resolve_script_dir` helper added to `core.sh` with BATS coverage (Codex, v0.1.1)

---

## What Is Pending

- [x] Wire lib-foundation subtree into k3d-manager — DONE in k3d-manager v0.7.0 (subtree at `scripts/lib/foundation/`)
- [ ] Sync deploy_cluster improvements back from k3d-manager local core.sh → lib-foundation core.sh (CLUSTER_NAME fix, provider helpers, if-count reduction)
- [ ] Remove duplicate mac+k3s guard in core.sh `deploy_cluster` (already removed in k3d-manager subtree snapshot; apply upstream)
- [ ] Route bare sudo in `_install_debian_helm` / `_install_debian_docker` through `_run_command` (Copilot flag — k3d-manager PR #24)
- [ ] Remote installer script integrity — checksum/signature verification for `_install_k3s`, `_install_istioctl`, `_install_bats_from_source`, `_install_copilot_from_release` (Copilot flag — k3d-manager PR #24; dev-only pattern, low priority)
- [ ] Drop colima support — delete `_install_colima` + `_install_mac_docker` from `system.sh`; update `_install_docker` mac case in `core.sh`. Sync from k3d-manager v0.7.1 once merged.
- [ ] Broader BATS coverage for remaining lib functions
- [ ] Consumer integration: `rigor-cli`
- [ ] Consumer integration: `shopping-carts`

---

## Known Constraints

| Item | Notes |
|---|---|
| `SCRIPT_DIR` dependency | `system.sh` sources `agent_rigor.sh` via `$SCRIPT_DIR` at load time — must resolve correctly in subtree layout |
| Contract stability | `_run_command`, `_detect_platform`, `_cluster_provider` — signature changes require all-consumer coordination |
| Clean env testing | BATS must run with `env -i` — ambient `SCRIPT_DIR` causes false passes |

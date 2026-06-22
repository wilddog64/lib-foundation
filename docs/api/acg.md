# ACG Module

`scripts/lib/acg/` is the optional browser-automation module imported from lib-acg.

## Public API

- `acg_*` functions manage the AWS sandbox lifecycle and Chrome CDP wiring.
- `gcp_*` functions extract and manage GCP sandbox credentials.
- `cdp.sh` provides the shared Chrome CDP helpers used by both APIs.

## Layout

- `scripts/lib/acg/cdp.sh` loads `scripts/lib/system.sh` when the host has not already loaded it.
- `scripts/lib/acg/acg.sh` and `scripts/lib/acg/gcp.sh` source `vars.sh` and use the module-local
  `playwright/`, `bin/`, `etc/`, and `tests/` trees.
- Node dependencies are isolated to the module and installed with `npm ci` from the module
  `package-lock.json`.

## Validation

- `npm run check` runs the module JS syntax checks.
- `npm test` runs the Jest unit tests.
- `npm run test:e2e` and `make credential-test` remain manual browser gates.

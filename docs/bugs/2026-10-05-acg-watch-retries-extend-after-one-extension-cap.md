# Bug: `acg_watch` retries extend after the sandbox's one extension and reports "Extend button not found"

**Status:** OPEN
**Filed:** 2026-10-05
**Branch:** `fix/acg-watch-one-extension-cap`
**Severity:** Low–Medium. Extend works, but every sandbox that lives past 7 h ends with a misleading
`ERROR` that reads as a broken selector and points the operator at the wrong problem.
**Files:** `scripts/lib/acg/acg.sh`, `scripts/lib/acg/playwright/acg_extend.js`,
`scripts/tests/lib/acg.bats`, `CHANGELOG.md`

## Symptom

From the operator's `make up` pane in k3d-manager (2026-10-05):

```
# first watcher wake, ~3.5h in — succeeds
Found extend button (immediately) with selector: [data-heap-id="Hands-on Playground - Click - AWS Sandbox - Extend Sandbox"]
Extend action complete (Immediate).

# second watcher wake, ~7h in — fails
INFO: Calculated remaining TTL: ~44 minutes
INFO: Within 1h extension window (44m remaining). Proceeding to extend...
INFO: Clicking Open Sandbox to reveal extend panel...
ERROR: Extend button not found or not visible after multiple attempts (including recovery)
INFO: [acg] Extend failed — open https://app.pluralsight.com/hands-on/playground/cloud-sandboxes to extend manually
```

## Root cause

An ACG sandbox lives 4 h and can be extended **once**, to 8 h total. `acg_watch`
(`scripts/lib/acg/acg.sh`) has no notion of that cap. It wakes every 12600 s (3.5 h):

| Wake | Remaining | Result |
|---|---|---|
| 3.5 h | ~30 m | in the ≤65 m window → extend succeeds (+4 h) |
| 7 h | ~45 m | in the window again → no Extend button exists → `ERROR` |
| 8 h | — | sandbox auto-shuts down |

`acg_extend.js` then reports the missing button with the same message it uses for a genuinely
broken selector, so the cap is indistinguishable from a regression.

The cap is taken from the operator's own sandbox notes (4 h + 4 h once). The failure screenshot
that would show the page timed out (`page.screenshot: Timeout 30000ms exceeded`), so the UI state
is not directly captured. The fix below is safe either way: if the cap were not real, the
watcher would merely skip a second extend that the UI already refused.

## Fix spec

### File 1 — `scripts/lib/acg/acg.sh`, function `acg_watch`

**1a.** In the `HELP` heredoc, replace:

```
Background sandbox TTL watcher. Extends the ACG sandbox every 3.5 hours
while the EC2 instance is alive. Stops automatically when the instance
is gone (after acg_teardown).
```

with:

```
Background sandbox TTL watcher. Extends the ACG sandbox every 3.5 hours
while the EC2 instance is alive. Stops automatically when the instance
is gone (after acg_teardown), or after one successful extension of the
same instance — ACG allows a single extension (8 hours total).
```

**1b.** Replace:

```bash
  local interval="${1:-12600}"
  _info "[acg] Sandbox watcher started (PID $$, extending every $((interval / 3600))h)"

  while true; do
    sleep "$interval"
    if [[ -z "$(_acg_get_instance_id 2>/dev/null)" ]]; then
      _info "[acg] Instance gone — watcher stopping."
      return 0
    fi
    _info "[acg] Extending sandbox TTL..."
    _acg_extend_playwright "${_ACG_SANDBOX_URL}" \
      || _info "[acg] Extend failed — open ${_ACG_SANDBOX_URL} to extend manually"
  done
```

with:

```bash
  local interval="${1:-12600}"
  local instance_id extended_instance="" extend_output
  _info "[acg] Sandbox watcher started (PID $$, extending every $((interval / 3600))h)"

  while true; do
    sleep "$interval"
    instance_id="$(_acg_get_instance_id 2>/dev/null)"
    if [[ -z "${instance_id}" ]]; then
      _info "[acg] Instance gone — watcher stopping."
      return 0
    fi
    if [[ "${instance_id}" == "${extended_instance}" ]]; then
      _info "[acg] Sandbox ${instance_id} was already extended once — ACG allows one extension (8h total)."
      _info "[acg] It will auto-shut down at its 8h mark; run 'make down' before then. Watcher stopping."
      return 0
    fi
    _info "[acg] Extending sandbox TTL..."
    if extend_output="$(_acg_extend_playwright "${_ACG_SANDBOX_URL}")"; then
      [[ -n "${extend_output}" ]] && printf '%s\n' "${extend_output}"
      if [[ "${extend_output}" == *"Extend action complete"* ]]; then
        extended_instance="${instance_id}"
      fi
    else
      [[ -n "${extend_output}" ]] && printf '%s\n' "${extend_output}"
      _info "[acg] Extend failed — open ${_ACG_SANDBOX_URL} to extend manually"
    fi
  done
```

Notes for the implementer:

- `_acg_extend_playwright` exits 0 **both** when it extends and when it skips because more than
  65 m remain ("Extension window not open yet"). Only a stdout containing `Extend action complete`
  (both the `(Immediate)` and the `Current expiry text:` variants in `acg_extend.js`) counts as an
  extension. A skip must not set `extended_instance`.
- `_info` writes to stderr, so `$(...)` captures only the node output that
  `_acg_extend_playwright` echoes; re-printing it keeps the watcher log unchanged.
- The state is in-process on purpose. A different instance id (a rebuilt sandbox) is never
  treated as extended. If the watcher restarts, it may attempt one extra extend; that is harmless.
- `acg_watch_start`'s launchd wrapper (`_acg_watch_write_wrapper`) is out of scope.

### File 2 — `scripts/lib/acg/playwright/acg_extend.js`

Replace:

```js
      throw new Error('Extend button not found or not visible after multiple attempts (including recovery)');
```

with:

```js
      throw new Error('Extend button not found or not visible after multiple attempts (including recovery). ACG allows one extension per sandbox (8h total) — if this sandbox was already extended, this is expected and it cannot be extended again.');
```

No other change to `acg_extend.js`.

### File 3 — `scripts/tests/lib/acg.bats`

Add tests that source `acg.sh` (the file's existing `setup`) and stub in-shell, after sourcing:
`sleep() { :; }`, `_acg_get_instance_id`, `_acg_extend_playwright`. Drive the loop with a counter
file under `${BATS_TEST_TMPDIR}` so `_acg_get_instance_id` returns the scripted sequence and then
`""` (which ends the loop). Count extend attempts in a sentinel file. Set
`_ACG_SANDBOX_URL='https://example.test/sandbox'`. Call `acg_watch 1` with `run`.

1. **stops after one successful extension:** instance ids `i-a, i-a, i-a`; extend stub prints
   `Extend action complete (Immediate).` → status 0, exactly **1** extend attempt, output contains
   `already extended once`, output does **not** contain `Extend failed`.
2. **a skip does not count as an extension:** ids `i-a, i-a, ""`; extend stub prints
   `INFO: Extension window not open yet (200m remaining). Skipping extension.` → status 0,
   **2** extend attempts, output does not contain `already extended once`.
3. **a failed extend does not count:** ids `i-a, i-a, ""`; extend stub prints
   `boom` and returns 1 → status 0, **2** attempts, output contains `Extend failed` and `boom`.
4. **a new instance is extended again:** ids `i-a, i-b, ""`; extend stub prints
   `Extend action complete. Current expiry text: x` → status 0, **2** attempts, output does not
   contain `already extended once`.

Use `[[ … ]] || false` or `run !`-style assertions for negatives; never a bare `! [[ … ]]`.

### File 4 — `CHANGELOG.md`

Under `## [Unreleased]` (create the heading above the newest version heading if it is absent) →
`### Fixed`: a prose entry explaining that `acg_watch` now stops after one successful extension of
the same instance, because ACG allows a single extension; previously its second wake (~7 h) found
no Extend button and logged a misleading "Extend button not found". A skipped extend (window not
open) and a failed extend do not count; a rebuilt sandbox is extended again. The
`acg_extend.js` not-found error now names the one-extension cap.

Flip this file's **Status** to FIXED.

## Definition of Done

- [ ] Pre-fix proof: test 1 is RED against the current `acg_watch` (it makes 2+ attempts). Tests 2–4
      guard against over-loosening and may pass pre-fix. Paste the output for all four.
- [ ] Mutation: delete the `*"Extend action complete"*` condition so any exit-0 sets
      `extended_instance`; test 2 goes red. Restore from a `$TMPDIR` snapshot and prove with `cmp`.
- [ ] `bats scripts/tests/lib/acg.bats` green; paste counts.
- [ ] `shellcheck scripts/lib/acg/acg.sh` — no new findings vs `HEAD`.
- [ ] `node --check scripts/lib/acg/playwright/acg_extend.js` passes.
- [ ] Changes left **unstaged**. Claude verifies and commits.

## What NOT to do

- Do NOT change the extend window (65 m), the 12600 s interval, the Ghost State recovery, or any
  selector in `acg_extend.js`.
- Do NOT touch `_acg_watch_write_wrapper`, `acg_watch_start`, or k3d-manager.
- Do NOT run node against Pluralsight, `make up`, or anything live. No AWS or browser access.
- Do NOT touch files outside those listed. No commit, push, PR, or `--no-verify`.

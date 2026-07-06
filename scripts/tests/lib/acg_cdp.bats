#!/usr/bin/env bats
# shellcheck shell=bash disable=SC1091,SC2329

setup() {
  SYSTEM_LIB="${BATS_TEST_DIRNAME}/../../lib/system.sh"
  CDP_LIB="${BATS_TEST_DIRNAME}/../../lib/acg/cdp.sh"
  # shellcheck source=/dev/null
  source "$SYSTEM_LIB"
  # shellcheck source=/dev/null
  source "$CDP_LIB"
}

bats_require_minimum_version 1.5.0

@test "_browser_launch: invokes _cdp_ensure_acg_session when Chrome is already running" {
  _command_exist() { [[ "$1" == curl ]]; }
  _run_command() { return 0; }
  _cdp_ensure_acg_session() { echo "session-check"; return 0; }
  export -f _command_exist _run_command _cdp_ensure_acg_session

  run _browser_launch
  [ "$status" -eq 0 ]
  [ "$output" = "session-check" ]

  unset -f _command_exist _run_command _cdp_ensure_acg_session
}

@test "_browser_launch: invokes _cdp_ensure_acg_session after launching Chrome" {
  launch_log="${BATS_TEST_TMPDIR}/launch.log"

  _command_exist() { [[ "$1" == curl ]]; }
  _run_command() { return 1; }
  _cdp_stop_chrome_cdp_agent() { :; }
  _cdp_remove_stale_singleton_lock() { :; }
  _info() { :; }
  uname() { echo "Darwin"; }
  mkdir() { command mkdir "$@"; }
  dirname() { command dirname "$@"; }
  open() { printf 'open %s\n' "$*" >>"$launch_log"; }
  _antigravity_browser_ready() { :; }
  _cdp_ensure_acg_session() { echo "launched-session-check"; return 0; }
  export -f _command_exist _run_command _cdp_stop_chrome_cdp_agent _cdp_remove_stale_singleton_lock _info uname mkdir dirname open _antigravity_browser_ready _cdp_ensure_acg_session

  run _browser_launch
  [ "$status" -eq 0 ]
  [ "$output" = "launched-session-check" ]

  unset -f _command_exist _run_command _cdp_stop_chrome_cdp_agent _cdp_remove_stale_singleton_lock _info uname mkdir dirname open _antigravity_browser_ready _cdp_ensure_acg_session
}

@test "_browser_launch: K3DM_ACG_SKIP_SESSION_CHECK=1 still bypasses the session check end-to-end" {
  _command_exist() { [[ "$1" == curl ]]; }
  _run_command() { return 0; }
  _info() { echo "$*"; }
  _err() { echo "$*"; return 1; }
  export -f _command_exist _run_command _info _err
  export K3DM_ACG_SKIP_SESSION_CHECK=1
  export _LIB_ACG_ROOT="${BATS_TEST_TMPDIR}/missing-acg-root"

  run _browser_launch
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping ACG/Pluralsight session check"* ]]

  unset K3DM_ACG_SKIP_SESSION_CHECK _LIB_ACG_ROOT
  unset -f _command_exist _run_command _info _err
}

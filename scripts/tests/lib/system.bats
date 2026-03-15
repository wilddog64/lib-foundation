#!/usr/bin/env bats
# shellcheck shell=bash

setup() {
  SYSTEM_LIB="${BATS_TEST_DIRNAME}/../../lib/system.sh"
  # shellcheck source=/dev/null
  source "$SYSTEM_LIB"
}

bats_require_minimum_version 1.5.0

@test "_run_command_resolve_sudo: no sudo flags → plain runner" {
  local -a runner=()
  _run_command_resolve_sudo runner "echo" 0 0 0
  [ "${runner[0]}" = "echo" ]
  [ "${#runner[@]}" -eq 1 ]
}

@test "_run_command_resolve_sudo: require_sudo unavailable → returns 127" {
  function sudo() { return 1; }
  export -f sudo
  local -a runner=()
  run -127 _run_command_resolve_sudo runner "echo" 0 1 0
  unset -f sudo
}

@test "_run_command_resolve_sudo: probe succeeds as user → plain runner" {
  local -a runner=()
  _run_command_resolve_sudo runner "true" 1 0 0 "--version"
  [ "${runner[0]}" = "true" ]
}

@test "_run_command: missing program → exits 127" {
  run -127 _run_command --soft -- __nonexistent_prog_xyz__
}

@test "_run_command: succeeds for simple command" {
  run _run_command -- echo hello
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "_run_command: --quiet suppresses error output on missing program" {
  run -127 _run_command --quiet --soft -- __nonexistent_prog_xyz__
  [ -z "$output" ]
}

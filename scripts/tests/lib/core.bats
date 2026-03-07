#!/usr/bin/env bats
# shellcheck shell=bash

setup() {
  CORE_LIB="${BATS_TEST_DIRNAME}/../../lib/core.sh"
}

_make_test_script() {
  local target="$1"
  cat <<'SCRIPT' > "$target"
#!/usr/bin/env bash
source "__CORE_LIB__"
SCRIPT_DIR="$(_resolve_script_dir)"
printf '%s\n' "$SCRIPT_DIR"
SCRIPT
  perl -0pi -e "s|__CORE_LIB__|$CORE_LIB|" "$target"
  chmod +x "$target"
}

@test "_resolve_script_dir returns absolute path" {
  test_dir="${BATS_TEST_TMPDIR}/direct"
  mkdir -p "$test_dir"
  script_path="$test_dir/original.sh"
  _make_test_script "$script_path"

  run "$script_path"
  [ "$status" -eq 0 ]
  expected="$(cd "$test_dir" && pwd -P)"
  [ "$output" = "$expected" ]
}

@test "_resolve_script_dir resolves symlinked script" {
  test_dir="${BATS_TEST_TMPDIR}/symlink"
  mkdir -p "$test_dir"
  script_path="$test_dir/original.sh"
  _make_test_script "$script_path"
  link_path="$test_dir/link.sh"
  ln -sf "$script_path" "$link_path"

  run "$link_path"
  [ "$status" -eq 0 ]
  expected="$(cd "$test_dir" && pwd -P)"
  [ "$output" = "$expected" ]
}

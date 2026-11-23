#!/usr/bin/env bats
# shellcheck shell=bash disable=SC1091,SC2329

_err() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

setup() {
  CORE_LIB="${BATS_TEST_DIRNAME}/../../lib/core.sh"
  STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  INSTALL_DIR="${BATS_TEST_TMPDIR}/install"
  mkdir -p "$STUB_BIN" "$INSTALL_DIR"
  export CORE_LIB STUB_BIN INSTALL_DIR
  export ISTIOCTL_URL_LOG="${BATS_TEST_TMPDIR}/curl.log"
  export ISTIOCTL_CHECKSUM_MODE="valid"
  : > "$ISTIOCTL_URL_LOG"
  cat > "$STUB_BIN/uname" <<'EOF'
#!/bin/sh
case "$1" in
  -s) printf '%s\n' "${TEST_UNAME_S:-Darwin}" ;;
  -m) printf '%s\n' "${TEST_UNAME_M:-arm64}" ;;
  *) exit 1 ;;
esac
EOF
  cat > "$STUB_BIN/curl" <<'EOF'
#!/bin/sh
url=""
for arg do
  case "$arg" in http://*|https://*) url="$arg" ;; esac
done
printf '%s\n' "$url" >> "$ISTIOCTL_URL_LOG"
case "$url" in
  */istioctl-*.tar.gz)
    out=""
    previous=""
    for arg do
      if [ "$previous" = "-o" ]; then out="$arg"; fi
      previous="$arg"
    done
    cp "$ISTIOCTL_FIXTURE" "$out"
    ;;
  *) exit 92 ;;
esac
EOF
  cat > "$STUB_BIN/shasum" <<'EOF'
#!/bin/sh
[ "$1" = "-a" ] && [ "$2" = "256" ] || exit 97
[ -f "$3" ] && [ "${3##*/}" = "istioctl.tar.gz" ] || exit 97
if [ "$ISTIOCTL_CHECKSUM_MODE" = mismatch ]; then
  printf '%s  %s\n' bad "$3"
else
  printf '%s  %s\n' "$ISTIOCTL_EXPECTED_SHA" "$3"
fi
EOF
  cat > "$STUB_BIN/rm" <<'EOF'
#!/bin/sh
for arg do
  case "$arg" in /tmp/istio-*) exit 0 ;; esac
done
exec /bin/rm "$@"
EOF
  chmod +x "$STUB_BIN/uname" "$STUB_BIN/curl" "$STUB_BIN/shasum" "$STUB_BIN/rm"
  export PATH="$STUB_BIN:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
  export ISTIOCTL_EXPECTED_SHA=2be63df4a0fedb10c9c5402cdbf2f666e84330f3c68aef244975225ea63ef675
  _make_fixture
}

_make_fixture() {
  local fixture_dir="${BATS_TEST_TMPDIR}/fixture"
  mkdir -p "$fixture_dir"
  cat > "$fixture_dir/istioctl" <<'EOF'
#!/bin/sh
# Captured client version format from m4-air, m2-air, and m5-air (2026-11-23).
printf '%s\n' 'client version: 1.31.4'
EOF
  chmod +x "$fixture_dir/istioctl"
  tar -czf "${BATS_TEST_TMPDIR}/istioctl.tar.gz" -C "$fixture_dir" istioctl
  export ISTIOCTL_FIXTURE="${BATS_TEST_TMPDIR}/istioctl.tar.gz"
}

_write_existing() {
  local path="$1" line="$2" mode="${3:-stdout}"
  mkdir -p "${path%/*}"
  if [ "$mode" = stderr ]; then
    printf '#!/bin/sh\nprintf "%%s\\n" "%s" >&2\n' "$line" > "$path"
  else
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$line" > "$path"
  fi
  chmod +x "$path"
}

@test "pin table returns the four published checksums and rejects unknown platforms" {
  source "$CORE_LIB"
  [ "$(_istioctl_pinned_sha256 1.31.4 osx arm64)" = 2be63df4a0fedb10c9c5402cdbf2f666e84330f3c68aef244975225ea63ef675 ]
  [ "$(_istioctl_pinned_sha256 1.31.4 osx amd64)" = da2398901943b3718566ca59311e045a0d99089006394fb573f34c23cd720311 ]
  [ "$(_istioctl_pinned_sha256 1.31.4 linux amd64)" = 7c00227d87f280c2450483e3518e3a73af62c057363b779ea80931c409e8852e ]
  [ "$(_istioctl_pinned_sha256 1.31.4 linux arm64)" = 3a1a82af8788059192d411e92d952c32d31a69bc20a039b3915f536d395e0c24 ]
  ! _istioctl_pinned_sha256 1.32.0 osx arm64
  ! _istioctl_pinned_sha256 1.31.4 freebsd arm64
}

@test "downloads the pinned archive on macOS arm64 and installs it" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  [ "$(command -v istioctl 2>/dev/null || true)" = "" ]
  source "$CORE_LIB"
  _run_command() { while [ "$1" != "--" ]; do shift; done; shift; "$@"; }
  _install_istioctl "$INSTALL_DIR"
  [ -x "$INSTALL_DIR/istioctl" ]
  [ "$(cat "$ISTIOCTL_URL_LOG")" = "https://github.com/istio/istio/releases/download/1.31.4/istioctl-1.31.4-osx-arm64.tar.gz" ]
  [[ "$($INSTALL_DIR/istioctl)" == "client version: 1.31.4" ]]
}

@test "downloads the pinned archive for macOS amd64" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  export TEST_UNAME_M=x86_64 ISTIOCTL_EXPECTED_SHA=da2398901943b3718566ca59311e045a0d99089006394fb573f34c23cd720311
  [ "$(command -v istioctl 2>/dev/null || true)" = "" ]
  source "$CORE_LIB"; _run_command() { while [ "$1" != "--" ]; do shift; done; shift; "$@"; }
  _install_istioctl "$INSTALL_DIR"
  [ -x "$INSTALL_DIR/istioctl" ]
  [[ "$(cat "$ISTIOCTL_URL_LOG")" == */istioctl-1.31.4-osx-amd64.tar.gz ]]
}

@test "downloads the pinned archive for Linux amd64 and arm64" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  export TEST_UNAME_S=Linux TEST_UNAME_M=x86_64 ISTIOCTL_EXPECTED_SHA=7c00227d87f280c2450483e3518e3a73af62c057363b779ea80931c409e8852e
  [ "$(command -v istioctl 2>/dev/null || true)" = "" ]
  source "$CORE_LIB"; _run_command() { while [ "$1" != "--" ]; do shift; done; shift; "$@"; }
  _install_istioctl "$INSTALL_DIR"
  [ -x "$INSTALL_DIR/istioctl" ]
  [[ "$(cat "$ISTIOCTL_URL_LOG")" == */istioctl-1.31.4-linux-amd64.tar.gz ]]
  rm -f "$INSTALL_DIR/istioctl"; : > "$ISTIOCTL_URL_LOG"
  export TEST_UNAME_M=aarch64 ISTIOCTL_EXPECTED_SHA=3a1a82af8788059192d411e92d952c32d31a69bc20a039b3915f536d395e0c24
  _install_istioctl "$INSTALL_DIR"
  [ -x "$INSTALL_DIR/istioctl" ]
  [[ "$(cat "$ISTIOCTL_URL_LOG")" == */istioctl-1.31.4-linux-arm64.tar.gz ]]
}

@test "accepts same-minor PATH and install_dir binaries without downloading" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  source "$CORE_LIB"; _run_command() { shift; "$@"; }
  _write_existing "$STUB_BIN/istioctl" 'client version: 1.31.1'
  [ "$(command -v istioctl)" = "$STUB_BIN/istioctl" ]
  run _install_istioctl "$INSTALL_DIR"
  [ "$status" -eq 0 ]; [[ "$output" == *"1.31.1"* && "$output" == *"1.31.4"* ]]
  [ ! -s "$ISTIOCTL_URL_LOG" ]
  rm "$STUB_BIN/istioctl"
  _write_existing "$INSTALL_DIR/istioctl" 'client version: 1.31.4'
  [ "$(command -v istioctl 2>/dev/null || true)" = "" ]
  run _install_istioctl "$INSTALL_DIR"
  [ "$status" -eq 0 ]; [[ "$output" == *"1.31.4"* ]]
  [ ! -s "$ISTIOCTL_URL_LOG" ]
}

@test "refuses another minor and malformed or stderr-only version output" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  source "$CORE_LIB"
  for line in 'client version: 1.32.0' 'client version: 1.30.0' '1.32.0'; do
    _write_existing "$STUB_BIN/istioctl" "$line"
    [ "$(command -v istioctl)" = "$STUB_BIN/istioctl" ]
    run bash -c 'source "$CORE_LIB"; _err() { printf "ERROR: %s\\n" "$*" >&2; exit 1; }; _install_istioctl "$INSTALL_DIR"' 
    [ "$status" -ne 0 ]
    [[ "$output" == *"$STUB_BIN/istioctl"* && "$output" == *"1.31.4"* && "$output" == *"brew unlink istioctl"* && "$output" == *"ISTIOCTL_VERSION"* && "$output" == *"releases"* ]]
    rm "$STUB_BIN/istioctl"
  done
  _write_existing "$STUB_BIN/istioctl" 'client version: 1.31.4' stderr
  [ "$(command -v istioctl)" = "$STUB_BIN/istioctl" ]
  run bash -c 'source "$CORE_LIB"; _err() { printf "ERROR: %s\\n" "$*" >&2; exit 1; }; _install_istioctl "$INSTALL_DIR"'
  [ "$status" -ne 0 ]; [[ "$output" == *"unknown"* && "$output" == *"$STUB_BIN/istioctl"* ]]
}

@test "ISTIOCTL_VERSION override accepts existing matching minor and refuses unsupported download" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  _write_existing "$STUB_BIN/istioctl" 'client version: 1.32.0'
  [ "$(command -v istioctl)" = "$STUB_BIN/istioctl" ]
  run env ISTIOCTL_VERSION=1.32.0 bash -c 'source "$CORE_LIB"; _run_command() { while [ "$1" != "--" ]; do shift; done; shift; "$@"; }; _install_istioctl "$INSTALL_DIR"'
  [ "$status" -eq 0 ]; [[ "$output" == *"1.32.0"* ]]
  [ ! -s "$ISTIOCTL_URL_LOG" ]
  rm "$STUB_BIN/istioctl"
  [ "$(command -v istioctl 2>/dev/null || true)" = "" ]
  run env ISTIOCTL_VERSION=1.32.0 bash -c 'source "$CORE_LIB"; _err() { printf "ERROR: %s\\n" "$*" >&2; exit 1; }; _install_istioctl "$INSTALL_DIR"'
  [ "$status" -ne 0 ]; [[ "$output" == *"no pinned checksum for 1.32.0-osx-arm64"* ]]
  [ ! -s "$ISTIOCTL_URL_LOG" ]
}

@test "checksum mismatch refuses installation without copying a binary" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  [ "$(command -v istioctl 2>/dev/null || true)" = "" ]
  export ISTIOCTL_CHECKSUM_MODE=mismatch
  run bash -c 'source "$CORE_LIB"; _run_command() { while [ "$1" != "--" ]; do shift; done; shift; "$@"; }; _err() { printf "ERROR: %s\\n" "$*" >&2; exit 1; }; _install_istioctl "$INSTALL_DIR"'
  [ "$status" -ne 0 ]; [[ "$output" == *"checksum"* ]]
  [ ! -e "$INSTALL_DIR/istioctl" ]
  [[ "$(cat "$ISTIOCTL_URL_LOG")" == */istioctl-1.31.4-osx-arm64.tar.gz ]]
}

@test "preserves the caller's EXIT trap" {
  [ "$INSTALL_DIR" = "${BATS_TEST_TMPDIR}/install" ]
  [ "$(command -v istioctl 2>/dev/null || true)" = "" ]
  run bash -c 'trap "echo sentinel" EXIT; source "$CORE_LIB"; _run_command() { while [ "$1" != "--" ]; do shift; done; shift; "$@"; }; _install_istioctl "$INSTALL_DIR"; trap -p EXIT'
  [ "$status" -eq 0 ]; [[ "$output" == *sentinel* ]]
}

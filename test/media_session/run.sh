#!/usr/bin/env bash
# Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
# All rights reserved.
# Use of this source code is governed by BSD 3-Clause license.
#
# Orchestrates every native media-session test suite available on the
# current host. Each per-platform subdirectory ships its own
# `run.sh` that compiles + runs the suite in the platform's native
# language; this script delegates to whichever ones the host can run.
#
# Platforms:
#   • darwin  — macOS + iOS (Swift; runs on macOS host).
#   • linux   — TBD (will be C++/GLib when MPRIS integration lands).
#   • windows — TBD (will be C++ when SMTC integration lands).
#   • android — TBD (will be Kotlin/JVM when MediaSession integration lands).
#
# Usage (from anywhere in the repo):
#   bash test/media_session/run.sh
#
# Exit codes:
#   0 — all available suites passed.
#   1 — at least one suite failed.
#   2 — environment problem (missing dependency etc.).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OS=$(uname -s)

failures=0
ran=0

run_suite() {
  local name="$1"
  local script="$2"
  if [ -x "$script" ]; then
    echo "▶ $name"
    if bash "$script"; then
      echo "✓ $name passed"
    else
      echo "✗ $name FAILED"
      failures=$((failures + 1))
    fi
    ran=$((ran + 1))
    echo
  fi
}

case "$OS" in
  Darwin)
    run_suite "darwin (Swift; macOS + iOS shared source)" "$HERE/darwin/run.sh"
    ;;
  Linux)
    if [ -x "$HERE/linux/run.sh" ]; then
      run_suite "linux (TBD)" "$HERE/linux/run.sh"
    else
      echo "(no Linux media-session implementation yet)"
    fi
    ;;
  MINGW*|CYGWIN*|MSYS*)
    if [ -x "$HERE/windows/run.sh" ]; then
      run_suite "windows (TBD)" "$HERE/windows/run.sh"
    else
      echo "(no Windows media-session implementation yet)"
    fi
    ;;
  *)
    echo "Unsupported host OS: $OS" >&2
    exit 2
    ;;
esac

if [ "$ran" -eq 0 ]; then
  echo "No applicable native media-session test suite for host OS '$OS'."
  exit 0
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures suite(s) failed."
  exit 1
fi
echo "All $ran suite(s) passed."

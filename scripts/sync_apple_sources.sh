#!/usr/bin/env bash
#
# Propagate the shared Apple Swift sources from `darwin/Sources/` into the
# per-platform iOS and macOS plugin source trees.
#
# `darwin/Sources/mpv_audio_kit/` is the single source of truth for the
# Swift that iOS and macOS share. The two platform copies are REAL FILES,
# not symlinks: `dart pub publish` does not preserve symlinks — it stores
# them in the tarball as regular files whose contents are the link-target
# path, which Xcode then tries to compile as Swift ("Expressions are not
# allowed at the top level"). So we duplicate on disk and keep the copies
# in sync with this script.
#
# Run it after editing anything under `darwin/Sources/`, before publishing.
# The drift / no-symlink invariant is enforced by
# `test/packaging/apple_sources_publish_safety_test.dart`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/darwin/Sources/mpv_audio_kit"

for plat in ios macos; do
  dst="$REPO_ROOT/$plat/mpv_audio_kit/Sources/mpv_audio_kit"
  mkdir -p "$dst"
  for f in "$SRC"/*.swift; do
    name="$(basename "$f")"
    rm -f "$dst/$name"   # drop any stale file or symlink first
    cp "$f" "$dst/$name"
    echo "synced $plat/mpv_audio_kit/Sources/mpv_audio_kit/$name"
  done
done

echo "done — Apple Swift sources synced from darwin/Sources/"

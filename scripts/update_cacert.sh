#!/usr/bin/env bash
# Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
# All rights reserved.
# Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

# =============================================================================
# update_cacert.sh
#
# Refreshes lib/assets/cacert.pem from curl.se's canonical mirror of the
# Mozilla CA bundle. Run before each release so HTTPS verification on
# Android (where mbedtls has no system trust store) keeps working as
# Mozilla rotates its trust list.
#
# The bundle is shipped as a Flutter asset
# (`lib/assets/cacert.pem`, registered in pubspec.yaml under
# `flutter.assets`), extracted to a temp file at Player construction by
# `lib/src/internals/tls_ca_bundle.dart`, and wired to mpv via
# `tls-ca-file`. See the comment in `Player._autoConfigureTlsCaBundle`.
#
# Usage (from project root or scripts/):
#   ./scripts/update_cacert.sh
#
# Exit code: 0 on success, non-zero if download or write fails.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This script lives in the package's scripts/ dir, so the package root is one up.
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$ROOT/lib/assets/cacert.pem"
URL="https://curl.se/ca/cacert.pem"

mkdir -p "$(dirname "$DEST")"

echo "Fetching $URL..."
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
curl -fsSL --retry 3 -o "$TMP" "$URL"

# Sanity: the response must look like a CA bundle. Reject anything that
# doesn't contain at least one PEM-encoded certificate (defensive against
# a captive-portal HTML page or a CDN error page silently overwriting
# the bundle).
if ! grep -q '^-----BEGIN CERTIFICATE-----' "$TMP"; then
  echo "ERROR: downloaded file does not contain any PEM certificate." >&2
  exit 1
fi

CA_COUNT="$(grep -c '^-----BEGIN CERTIFICATE-----' "$TMP")"
if (( CA_COUNT < 50 )); then
  echo "ERROR: only $CA_COUNT certificates in bundle — looks truncated." >&2
  exit 1
fi

# Print bundle metadata so the operator can sanity-check the version.
HEADER_DATE="$(grep -m1 'Certificate data from Mozilla' "$TMP" || echo '(no date header)')"

mv -f "$TMP" "$DEST"
trap - EXIT

echo "→ $DEST"
echo "  $HEADER_DATE"
echo "  Total CAs: $CA_COUNT"
echo "  Size:      $(wc -c < "$DEST" | tr -d ' ') bytes"

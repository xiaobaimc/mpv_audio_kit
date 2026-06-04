#!/usr/bin/env bash
# Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
# All rights reserved.
# Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
#
# Generates the codec coverage fixtures consumed by both the host test
# suite (test/fixtures/codec/) and the on-device test app
# (test_app/assets/fixtures/codec/). Run this whenever the codec matrix
# changes; commit the regenerated files to git.
#
# The two destinations exist because Flutter's asset bundler ships the
# `test_app/assets/` tree into the iOS / Android app binary, while the
# host suite reads files via an absolute filesystem path. There's no
# single location that satisfies both — duplication is unavoidable, so
# this script is the single source of truth that keeps both copies in
# lock-step.
#
# Requires: ffmpeg in PATH. A vanilla `brew install ffmpeg` on macOS or
# `apt install ffmpeg` on Ubuntu is sufficient. The matrix focuses on what
# every default ffmpeg can encode reproducibly. Codecs whose encoder is
# absent from the local ffmpeg are auto-skipped (the corresponding decoder
# is exercised by the registry-presence test in the Dart suite — search
# for `decoder_registry_coverage_test.dart`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This script lives in the package's scripts/ dir, so the package root is one up.
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST_DIR="$REPO_ROOT/test/fixtures/codec"
DEVICE_DIR="$REPO_ROOT/test_app/assets/fixtures/codec"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg not found in PATH." >&2
  echo "Install it with 'brew install ffmpeg' (macOS) or 'apt install ffmpeg' (Linux) and retry." >&2
  exit 1
fi

mkdir -p "$HOST_DIR" "$DEVICE_DIR"

TMP_DIR="$(mktemp -d -t mpv_audio_kit_fixtures.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Source: 1-second 440Hz sine wave at 96 kHz / 32-bit float. Every codec
# fixture is a re-encode of this single master, so a behavioural diff
# across codec runs reflects codec behaviour and not source variability.
MASTER="$TMP_DIR/master.wav"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "sine=frequency=440:duration=1:sample_rate=96000" \
  -ac 2 -c:a pcm_f32le \
  "$MASTER"

emit() {
  local out_name="$1"; shift
  local out_path="$TMP_DIR/$out_name"
  ffmpeg -hide_banner -loglevel error -y -i "$MASTER" "$@" "$out_path"
  cp "$out_path" "$HOST_DIR/$out_name"
  cp "$out_path" "$DEVICE_DIR/$out_name"
  local size
  size="$(stat -f%z "$out_path" 2>/dev/null || stat -c%s "$out_path")"
  printf '  %-32s %8s bytes\n' "$out_name" "$size"
}

# Same as emit, but skips silently if the encoder isn't compiled into
# the local ffmpeg. Used for codecs whose encoder is optional in default
# ffmpeg builds (DTS, WMA family, etc.). The registry-presence test in
# the Dart suite still covers the decoder side regardless.
emit_if_encoder() {
  local encoder="$1"; shift
  if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -qE "^ A.* $encoder " ; then
    printf '  %-32s skipped (encoder %s missing)\n' "$1" "$encoder"
    return
  fi
  emit "$@"
}

echo "Generating codec coverage fixtures…"
echo

echo "Lossy:"
emit mp3_44100_stereo.mp3      -ar 44100 -ac 2 -c:a libmp3lame -b:a 128k
emit mp3_48000_mono.mp3        -ar 48000 -ac 1 -c:a libmp3lame -b:a 128k
emit aac_lc_44100.m4a          -ar 44100 -ac 2 -c:a aac        -b:a 128k
emit aac_adts_44100.aac        -ar 44100 -ac 2 -c:a aac        -b:a 128k -f adts

echo
echo "Lossless:"
emit flac_44100_16bit.flac     -ar 44100  -ac 2 -sample_fmt s16 -c:a flac
emit flac_88200_24bit.flac     -ar 88200  -ac 2 -sample_fmt s32 -c:a flac
emit flac_192000_24bit.flac    -ar 192000 -ac 2 -sample_fmt s32 -c:a flac
emit alac_44100.m4a            -ar 44100  -ac 2 -c:a alac

echo
echo "Open-source:"
emit opus_48000_stereo.opus    -ar 48000 -ac 2 -c:a libopus -b:a 96k
# ffmpeg ships TWO vorbis encoders: `libvorbis` (xiph, full quality) and
# `vorbis` (native, marked experimental). Vanilla `brew install ffmpeg`
# omits libvorbis entirely on recent versions, so we prefer it when
# available and fall back to the native encoder otherwise. The decoded
# stream is identical from libmpv's point of view — only encoder-side
# quality differs, irrelevant for a 1-second sine fixture.
if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q ' libvorbis '; then
  emit vorbis_44100_stereo.ogg -ar 44100 -ac 2 -c:a libvorbis -b:a 96k
else
  emit vorbis_44100_stereo.ogg -ar 44100 -ac 2 -c:a vorbis -strict experimental -b:a 96k
fi

echo
echo "Dolby:"
emit ac3_48000_stereo.ac3      -ar 48000 -ac 2 -c:a ac3  -b:a 192k
emit eac3_48000_stereo.eac3    -ar 48000 -ac 2 -c:a eac3 -b:a 192k

echo
echo "Uncompressed PCM:"
emit wav_pcm_s16_44100.wav     -ar 44100 -ac 2 -c:a pcm_s16le
emit wav_pcm_s24_48000.wav     -ar 48000 -ac 2 -c:a pcm_s24le
emit wav_pcm_s32_96000.wav     -ar 96000 -ac 2 -c:a pcm_s32le
emit aiff_pcm_44100.aiff       -ar 44100 -ac 2 -c:a pcm_s16be -f aiff

echo
echo "Pro / broadcast / lossless extras (encoder-conditional):"
emit_if_encoder dca       dts_48000_stereo.dts        -ar 48000 -ac 2 -c:a dca -strict -2 -b:a 768k
emit_if_encoder mlp       mlp_48000_stereo.mlp        -ar 48000 -ac 2 -c:a mlp -strict -2
emit_if_encoder truehd    truehd_48000_stereo.thd     -ar 48000 -ac 2 -c:a truehd -strict -2
emit_if_encoder tta       tta_44100.tta               -ar 44100 -ac 2 -c:a tta
emit_if_encoder wavpack   wavpack_44100.wv            -ar 44100 -ac 2 -c:a wavpack
emit_if_encoder mp2       mp2_44100.mp2               -ar 44100 -ac 2 -c:a mp2 -b:a 192k

echo
echo "WMA family (encoder-conditional):"
emit_if_encoder wmav1     wma_v1_44100.wma            -ar 44100 -ac 2 -c:a wmav1 -b:a 128k
emit_if_encoder wmav2     wma_v2_44100.wma            -ar 44100 -ac 2 -c:a wmav2 -b:a 128k

echo
echo "ADPCM (telephony / legacy):"
emit_if_encoder adpcm_ms      adpcm_ms_22050.wav      -ar 22050 -ac 2 -c:a adpcm_ms
emit_if_encoder adpcm_ima_qt  adpcm_ima_qt_22050.mov  -ar 22050 -ac 2 -c:a adpcm_ima_qt -f mov

echo
echo "PCM long-tail (μ-law / a-law / float / big-endian):"
emit_if_encoder pcm_alaw   pcm_alaw_8000.wav          -ar 8000  -ac 2 -c:a pcm_alaw
emit_if_encoder pcm_mulaw  pcm_mulaw_8000.wav         -ar 8000  -ac 2 -c:a pcm_mulaw
emit_if_encoder pcm_f32le  pcm_f32le_44100.wav        -ar 44100 -ac 2 -c:a pcm_f32le
emit_if_encoder pcm_f64le  pcm_f64le_44100.wav        -ar 44100 -ac 2 -c:a pcm_f64le
emit_if_encoder pcm_s32be  pcm_s32be_48000.aiff       -ar 48000 -ac 2 -c:a pcm_s32be -f aiff
emit_if_encoder pcm_s24be  pcm_s24be_48000.aiff       -ar 48000 -ac 2 -c:a pcm_s24be -f aiff

echo
echo "Containers:"
emit mka_flac.mka              -ar 44100 -ac 2 -c:a flac
emit webm_opus.webm            -ar 48000 -ac 2 -c:a libopus -b:a 96k

echo
echo "Done. Files written to:"
echo "  $HOST_DIR"
echo "  $DEVICE_DIR"

// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

import '../models/cover_art.dart';
import '../models/media_session.dart';
import '../player/player_state.dart';
import '../types/sealed/media_session_artwork.dart';
import '../types/sealed/media_session_command.dart';
import 'media_session_channel.dart';
import 'media_session_inputs.dart';

/// Orchestrates the bridge between the [Player]'s reactive state and
/// the OS media session.
///
/// Subscribes to a focused subset of [PlayerStream]:
///
/// - `playWhenReady` / `rate` / `seekCompleted` / `seekable` / `loop` /
///   `shuffle` → push a fresh playback snapshot (the OS extrapolates
///   position forward from this, so we never push raw `time-pos`
///   ticks). The OS play/pause state is driven by `playWhenReady` (user
///   intent), which is stable across seeks — so the button never
///   flickers while scrubbing. The `seekCompleted` push re-syncs the
///   landed position to the OS slider.
/// - `duration` / `metadata` / `coverArt` / `mediaTitle` → push a
///   fresh metadata snapshot.
/// - `mediaSession` (the config field itself) → push a config update
///   when the consumer reconfigures while enabled.
///
/// Computes effective metadata (override > mpv-derived) using the
/// current [PlayerState] snapshot at push time, so streams are only
/// signal sources — never source of truth.
///
/// Incoming commands from the OS event channel are routed through
/// [onCommand]. The owner ([_MediaSessionModule]) is responsible for
/// applying them to the [Player] and forwarding to consumer
/// subscribers — this class is transport-only.
///
/// Lifecycle: instantiated on first `setMediaSession(non-null)`,
/// disposed on `setMediaSession(null)` or `Player.dispose()`.
@internal
class MediaSessionController {
  final PlayerState Function() _stateSnapshot;
  final MediaSessionInputs _inputs;
  final void Function(MediaSessionCommand) _onCommand;
  final MediaSessionChannel _channel;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<MediaSessionCommand>? _commandSub;
  bool _disposed = false;

  MediaSessionController._({
    required PlayerState Function() stateSnapshot,
    required MediaSessionInputs inputs,
    required void Function(MediaSessionCommand) onCommand,
    MediaSessionChannel? channel,
  })  : _stateSnapshot = stateSnapshot,
        _inputs = inputs,
        _onCommand = onCommand,
        _channel = channel ?? MediaSessionChannel();

  /// Wires the controller up and pushes the initial full state to the
  /// native side. Returns once the initial `enable` call has been
  /// dispatched (native ACK is fire-and-forget — see
  /// [MediaSessionChannel] for the rationale).
  ///
  /// [inputs] declares the exact slice of Player state the controller
  /// consumes. Production builds it via
  /// `MediaSessionInputs.fromPlayer(...)`; tests can build a
  /// [MediaSessionInputs] from raw [StreamController]s and drive
  /// arbitrary event sequences.
  static Future<MediaSessionController> create({
    required PlayerState Function() stateSnapshot,
    required MediaSessionInputs inputs,
    required void Function(MediaSessionCommand) onCommand,
    @visibleForTesting MediaSessionChannel? channel,
  }) async {
    final c = MediaSessionController._(
      stateSnapshot: stateSnapshot,
      inputs: inputs,
      onCommand: onCommand,
      channel: channel,
    );
    await c._wireUp();
    return c;
  }

  Future<void> _wireUp() async {
    // Playback-state signals — drive `updatePlayback`. The OS button
    // tracks `playWhenReady` (user intent), which is flicker-free across
    // seeks. The `seekCompleted` push re-syncs the landed position on
    // EVERY restart (seek + file-load) so the OS slider tracks mpv (e.g.
    // snaps to ~0 on playlist auto-advance).
    _subscriptions.add(_inputs.playWhenReady.listen((_) => _pushPlayback()));
    _subscriptions.add(_inputs.rate.listen((_) => _pushPlayback()));
    _subscriptions.add(_inputs.seekCompleted.listen((_) => _pushPlayback()));
    // Seekable governs both the OS scrubber (enabled/disabled) and
    // the "live stream" UI mode — re-push when it flips.
    _subscriptions.add(_inputs.seekable.listen((_) => _pushPlayback()));
    // Loop + shuffle drive the OS repeat / shuffle button visual state
    // (Apple's `currentRepeatType` / `currentShuffleType`,
    // MPRIS `LoopStatus` / `Shuffle`, MediaSession actions).
    _subscriptions.add(_inputs.loop.listen((_) => _pushPlayback()));
    _subscriptions.add(_inputs.shuffle.listen((_) => _pushPlayback()));

    // Metadata signals — drive `updateMetadata`.
    _subscriptions.add(_inputs.duration.listen((_) => _pushMetadata()));
    _subscriptions.add(_inputs.metadata.listen((_) => _pushMetadata()));
    _subscriptions.add(_inputs.coverArt.listen((_) => _pushMetadata()));
    _subscriptions.add(_inputs.mediaTitle.listen((_) => _pushMetadata()));

    // Config changes — drive `updateConfig`, AND re-push metadata. The
    // metadata-override fields (title / artist / album / artwork /
    // duration) live in the metadata snapshot, not the config map, so a
    // `setMediaSession(copyWith(title: ...))` must also re-push metadata
    // or the override would never reach the OS until an unrelated mpv
    // metadata tick happened to fire (often never on a static track).
    _subscriptions.add(_inputs.mediaSession.listen((session) {
      if (session == null) return;
      _channel.updateConfig(session);
      _pushMetadata();
    }),);

    // Inbound commands from the OS event channel.
    _commandSub = _channel.commandStream.listen(_onCommand);

    // Push the initial full state.
    final state = _stateSnapshot();
    final session = state.mediaSession;
    if (session == null) return;
    await _channel.enable(
      session: session,
      metadata: _computeMetadata(),
      playback: _computePlayback(),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _commandSub?.cancel();
    _commandSub = null;
    await _channel.disable();
  }

  // ── Push helpers ────────────────────────────────────────────────────

  /// Pushes a playback snapshot.
  ///
  /// The OS play/pause state comes from `playWhenReady` (user intent),
  /// not `core-idle` — so it stays stable while mpv churns through the
  /// seek/restart cycle and the scrub-bar button never flickers. No
  /// seek-transient masking is needed.
  Future<void> _pushPlayback() async {
    if (_disposed) return;
    if (_stateSnapshot().mediaSession == null) return;
    await _channel.updatePlayback(_computePlayback());
  }

  Future<void> _pushMetadata() async {
    if (_disposed) return;
    if (_stateSnapshot().mediaSession == null) return;
    await _channel.updateMetadata(_computeMetadata());
  }

  // ── Snapshot builders ───────────────────────────────────────────────

  MediaSessionMetadataSnapshot _computeMetadata() {
    final state = _stateSnapshot();
    final override = state.mediaSession;
    final mpvMeta = state.metadata;

    // Title falls through three layers: explicit override → mpv's
    // `metadata.title` tag → mpv's `media-title` (which itself falls
    // back to the filename for files without a title tag).
    final title = override?.title ??
        _firstTagValue(mpvMeta, const ['title']) ??
        (state.mediaTitle.isEmpty ? null : state.mediaTitle);

    final artist = override?.artist ??
        _firstTagValue(mpvMeta, const ['artist', 'album_artist']);

    final album = override?.album ?? _firstTagValue(mpvMeta, const ['album']);

    final duration = override?.duration ??
        (state.duration == Duration.zero ? null : state.duration);

    return MediaSessionMetadataSnapshot(
      title: title,
      artist: artist,
      album: album,
      artwork: _resolveArtwork(override, state.coverArt),
      duration: duration,
    );
  }

  CoverArt? _resolveArtwork(MediaSession? override, CoverArt? embedded) {
    final artwork = override?.artwork ?? MediaSessionArtwork.embedded;
    return switch (artwork) {
      MediaSessionArtworkNone() => null,
      MediaSessionArtworkCustom(:final cover) => cover,
      MediaSessionArtworkEmbedded() => embedded,
    };
  }

  MediaSessionPlaybackSnapshot _computePlayback() {
    final state = _stateSnapshot();
    return MediaSessionPlaybackSnapshot(
      playing: state.playWhenReady,
      position: state.position,
      rate: state.rate,
      seekable: state.seekable,
      loop: state.loop,
      shuffle: state.shuffle,
    );
  }

  /// First non-empty value among [keys] in the mpv metadata map, matched
  /// **case-insensitively**: mpv's tag-key casing varies by container
  /// (ID3v2 / Vorbis come back lowercase, but MP4 / iTunes atoms do not),
  /// so never assume a fixed case. [keys] are given lowercase; the list
  /// also carries semantic fallbacks (e.g. `album_artist` when `artist`
  /// is absent).
  String? _firstTagValue(Map<String, String> meta, List<String> keys) {
    for (final key in keys) {
      for (final entry in meta.entries) {
        if (entry.value.isNotEmpty && entry.key.toLowerCase() == key) {
          return entry.value;
        }
      }
    }
    return null;
  }
}

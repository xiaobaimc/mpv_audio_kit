// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../internals/unset_sentinel.dart';
import '../types/enums/interruption_policy.dart';
import '../types/enums/media_action.dart';
import '../types/sealed/media_session_artwork.dart';
import 'cover_art.dart';

/// Configuration and metadata for the OS media session — the
/// lockscreen / SMTC / MPRIS entry, Bluetooth AVRCP, headset
/// buttons, and (on iOS/Android) the AVAudioSession / AudioFocus
/// integration.
///
/// Apply via [Player.setMediaSession]; pass `null` to disable the
/// session entirely. Only one [Player] instance per process can have
/// an active media session at a time — attempting to enable a second
/// throws [StateError].
///
/// **Metadata fields** ([title], [artist], [album], [duration]) are
/// *overrides*: a `null` field falls back to the value derived from
/// mpv (`metadata.title` / `media-title`, `metadata.artist`,
/// `metadata.album`, `duration`); an empty string is an explicit
/// blank. [artwork] is a typed choice — see [MediaSessionArtwork].
///
/// **Config fields** (everything else) are always applied verbatim
/// when the session is enabled.
///
/// Updates use the standard [copyWith] pattern:
///
/// ```dart
/// // Enable with all defaults — metadata comes from mpv
/// await player.setMediaSession(const MediaSession());
///
/// // Override the title for the current track
/// await player.setMediaSession(
///   (player.state.mediaSession ?? const MediaSession())
///       .copyWith(title: 'My Custom Title'),
/// );
///
/// // Disable
/// await player.setMediaSession(null);
/// ```
class MediaSession {
  // ── Metadata override (null = derive from mpv) ─────────────────────

  /// Track title shown on the lockscreen / SMTC top line. `null` falls
  /// back to mpv's `metadata.title` (or `media-title` if absent).
  final String? title;

  /// Artist name shown beneath the title. `null` falls back to mpv's
  /// `metadata.artist`.
  final String? artist;

  /// Album name shown as a third metadata line on lockscreens that
  /// surface it (iOS, macOS, Windows SMTC). Often hidden on Android's
  /// compact notification. `null` falls back to mpv's
  /// `metadata.album`.
  final String? album;

  /// Artwork shown on the OS media session. Defaults to
  /// [MediaSessionArtwork.embedded] (the file's embedded cover); use
  /// [MediaSessionArtwork.custom] for your own image, or
  /// [MediaSessionArtwork.none] to suppress it.
  final MediaSessionArtwork artwork;

  /// Track length. Drives the lockscreen scrubber's end-of-track
  /// position. `null` falls back to mpv's `duration`.
  final Duration? duration;

  // ── Capabilities ───────────────────────────────────────────────────

  /// Capabilities advertised to the OS. The system shows only the
  /// buttons it has UI space for (lockscreens typically show 3–4),
  /// but the wider set is offered to Siri / Google Assistant /
  /// Android Auto / CarPlay surfaces.
  final Set<MediaAction> actions;

  // ── Audio interruption handling ────────────────────────────────────

  /// How the player reacts to an OS audio interruption (phone call,
  /// Siri, another app taking focus). Defaults to
  /// [InterruptionPolicy.pauseAndResume]; honoured on iOS / Android and
  /// a no-op on macOS / Linux / Windows. See [InterruptionPolicy].
  final InterruptionPolicy interruptionPolicy;

  // ── Skip intervals ─────────────────────────────────────────────────

  /// Interval used by the system "skip forward N seconds" button when
  /// [MediaAction.fastForward] is in [actions]. Default 15 seconds —
  /// matches Apple Podcasts' default and audio_service's
  /// `fastForwardInterval`. The OS shows this number on the skip icon
  /// (e.g. "+15") on iOS / macOS / Android Auto.
  final Duration fastForwardInterval;

  /// Interval used by the system "skip backward N seconds" button when
  /// [MediaAction.rewind] is in [actions]. Default 15 seconds —
  /// symmetric with [fastForwardInterval].
  final Duration rewindInterval;

  /// Set of selectable playback rates surfaced by the OS Now Playing
  /// rate-picker when [MediaAction.setPlaybackRate] is in [actions].
  /// Default `[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]` matches Apple
  /// Podcasts. The OS may show only a subset depending on the
  /// surface (CarPlay, lockscreen, Control Center).
  final List<double> supportedPlaybackRates;

  // ── App identity ───────────────────────────────────────────────────

  /// Display name shown by MPRIS (Linux) and SMTC (Windows) for the
  /// app identity. `null` defers to the executable / bundle name.
  /// macOS, iOS and Android always use the bundle display name.
  final String? appName;

  /// App icon shown alongside the now-playing entry on platforms that
  /// surface one (SMTC, MPRIS). macOS, iOS and Android use the system
  /// app icon. `null` defers to the platform default.
  final CoverArt? appIcon;

  /// Creates a media-session configuration. Every field is optional and
  /// carries a sensible default; metadata fields default to deriving
  /// their value from the playing file.
  const MediaSession({
    this.title,
    this.artist,
    this.album,
    this.artwork = MediaSessionArtwork.embedded,
    this.duration,
    this.actions = const {
      MediaAction.play,
      MediaAction.pause,
      MediaAction.playPause,
      MediaAction.next,
      MediaAction.previous,
      MediaAction.seek,
    },
    this.interruptionPolicy = InterruptionPolicy.pauseAndResume,
    this.fastForwardInterval = const Duration(seconds: 15),
    this.rewindInterval = const Duration(seconds: 15),
    this.supportedPlaybackRates = const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
    this.appName,
    this.appIcon,
  });

  /// Returns a copy of this configuration with the given fields replaced.
  ///
  /// The nullable override fields ([title], [artist], [album], [duration],
  /// [appName], [appIcon]) accept `null` to CLEAR the override back to the
  /// mpv-derived value: passing `null` is distinguished from omitting the
  /// argument (which keeps the current value). The non-nullable fields keep
  /// their current value when omitted.
  MediaSession copyWith({
    Object? title = unset,
    Object? artist = unset,
    Object? album = unset,
    MediaSessionArtwork? artwork,
    Object? duration = unset,
    Set<MediaAction>? actions,
    InterruptionPolicy? interruptionPolicy,
    Duration? fastForwardInterval,
    Duration? rewindInterval,
    List<double>? supportedPlaybackRates,
    Object? appName = unset,
    Object? appIcon = unset,
  }) =>
      MediaSession(
        title: identical(title, unset) ? this.title : title as String?,
        artist: identical(artist, unset) ? this.artist : artist as String?,
        album: identical(album, unset) ? this.album : album as String?,
        artwork: artwork ?? this.artwork,
        duration:
            identical(duration, unset) ? this.duration : duration as Duration?,
        actions: actions ?? this.actions,
        interruptionPolicy: interruptionPolicy ?? this.interruptionPolicy,
        fastForwardInterval: fastForwardInterval ?? this.fastForwardInterval,
        rewindInterval: rewindInterval ?? this.rewindInterval,
        supportedPlaybackRates:
            supportedPlaybackRates ?? this.supportedPlaybackRates,
        appName: identical(appName, unset) ? this.appName : appName as String?,
        appIcon:
            identical(appIcon, unset) ? this.appIcon : appIcon as CoverArt?,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaSession) return false;
    if (other.title != title ||
        other.artist != artist ||
        other.album != album ||
        other.artwork != artwork ||
        other.duration != duration ||
        other.interruptionPolicy != interruptionPolicy ||
        other.fastForwardInterval != fastForwardInterval ||
        other.rewindInterval != rewindInterval ||
        other.appName != appName ||
        other.appIcon != appIcon) {
      return false;
    }
    if (other.actions.length != actions.length) return false;
    for (final a in actions) {
      if (!other.actions.contains(a)) return false;
    }
    if (other.supportedPlaybackRates.length != supportedPlaybackRates.length) {
      return false;
    }
    for (var i = 0; i < supportedPlaybackRates.length; i++) {
      if (other.supportedPlaybackRates[i] != supportedPlaybackRates[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        title,
        artist,
        album,
        artwork,
        duration,
        Object.hashAllUnordered(actions),
        interruptionPolicy,
        fastForwardInterval,
        rewindInterval,
        Object.hashAll(supportedPlaybackRates),
        appName,
        appIcon,
      );

  @override
  String toString() => 'MediaSession(title: $title, artist: $artist, '
      'album: $album, artwork: $artwork, duration: $duration, '
      'actions: $actions, '
      'interruptionPolicy: $interruptionPolicy, '
      'fastForwardInterval: $fastForwardInterval, '
      'rewindInterval: $rewindInterval, '
      'supportedPlaybackRates: $supportedPlaybackRates, '
      'appName: $appName, appIcon: $appIcon)';
}

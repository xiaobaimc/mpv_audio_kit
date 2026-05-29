// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../../models/cover_art.dart';

/// Artwork shown on the OS media session (lockscreen, Control Center,
/// SMTC, MPRIS). Set via [MediaSession.artwork].
///
/// - [MediaSessionArtwork.embedded] (default): the picture embedded in
///   the playing file, exposed by [PlayerStream.coverArt].
/// - [MediaSessionArtwork.custom]: a specific image you supply, ignoring
///   the file's embedded cover.
/// - [MediaSessionArtwork.none]: no artwork — the OS shows its own
///   placeholder (typically the app icon).
sealed class MediaSessionArtwork {
  const MediaSessionArtwork._();

  /// Use the picture embedded in the playing file. Default.
  static const MediaSessionArtwork embedded = MediaSessionArtworkEmbedded._();

  /// Show no artwork.
  static const MediaSessionArtwork none = MediaSessionArtworkNone._();

  /// Show [cover], ignoring any cover embedded in the file.
  const factory MediaSessionArtwork.custom(CoverArt cover) =
      MediaSessionArtworkCustom._;
}

/// The [MediaSessionArtwork.embedded] variant: artwork from the playing
/// file's embedded cover.
final class MediaSessionArtworkEmbedded extends MediaSessionArtwork {
  const MediaSessionArtworkEmbedded._() : super._();

  @override
  String toString() => 'MediaSessionArtwork.embedded';
}

/// The [MediaSessionArtwork.none] variant: show no artwork.
final class MediaSessionArtworkNone extends MediaSessionArtwork {
  const MediaSessionArtworkNone._() : super._();

  @override
  String toString() => 'MediaSessionArtwork.none';
}

/// The [MediaSessionArtwork.custom] variant: a consumer-supplied [cover].
final class MediaSessionArtworkCustom extends MediaSessionArtwork {
  /// The image to publish.
  final CoverArt cover;

  const MediaSessionArtworkCustom._(this.cover) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaSessionArtworkCustom && other.cover == cover;

  @override
  int get hashCode => Object.hash(MediaSessionArtworkCustom, cover);

  @override
  String toString() => 'MediaSessionArtwork.custom($cover)';
}

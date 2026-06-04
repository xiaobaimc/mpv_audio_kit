// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
part of 'player.dart';

/// Playlist setters: queue mutation (add / remove / move / replace),
/// navigation (next / previous / jump), repeat / shuffle / prefetch
/// modes.
mixin _PlaylistModule on _PlayerBase {
  /// Appends [media] to the end of the current playlist.
  ///
  /// `media.httpHeaders` ride along as the 4th `loadfile` argument
  /// (mpv 0.38+: `loadfile <url> append -1 <opts>`), so mpv scopes
  /// them as file-local for this exact entry — even if the entry
  /// only loads minutes later when playback advances.
  Future<void> add(Media media) async {
    _checkNotDisposed();
    await _ready;
    _validateLoadOptions(media);
    _mediaCache[media.uri] = media;
    // TLS gate: HTTPS appends right after construction must see
    // `tls-ca-file` before loadfile fires.
    final tls = _tlsBundleReady;
    final resolved = await resolveUri(media.uri);
    await tls;
    if (_disposed) {
      await resolved.dispose?.call();
      return;
    }
    _mediaCache[resolved.uri] = media;
    final opts = _buildLoadfileOptions(media);
    if (opts.isEmpty) {
      _command(['loadfile', resolved.uri, 'append']);
    } else {
      _command(['loadfile', resolved.uri, 'append', '-1', opts]);
    }
  }

  /// Removes the track at [index] from the playlist.
  Future<void> remove(int index) async {
    _checkNotDisposed();
    await _ready;
    _command(['playlist-remove', index.toString()]);
  }

  /// Skips to the next track.
  Future<void> next() async {
    _checkNotDisposed();
    await _ready;
    _command(['playlist-next']);
  }

  /// Skips to the previous track.
  Future<void> previous() async {
    _checkNotDisposed();
    await _ready;
    _command(['playlist-prev']);
  }

  /// Jumps to the track at [index] in the playlist and starts playback.
  ///
  /// Unpauses synchronously *before* issuing the playlist jump so the new
  /// track starts playing as soon as `MPV_EVENT_FILE_LOADED` arrives — no
  /// shared `_pendingPlay` field to race on with concurrent `open()` calls.
  Future<void> jump(int index) async {
    _checkNotDisposed();
    await _ready;
    _prop('pause', 'no');
    _command(['playlist-play-index', index.toString()]);
  }

  /// Moves the track at [from] to position [to].
  Future<void> move(int from, int to) async {
    _checkNotDisposed();
    await _ready;
    _command(['playlist-move', from.toString(), to.toString()]);
  }

  /// Replaces the track at [index] with a new [media] item.
  ///
  /// `media.httpHeaders` ride along as file-local options on the
  /// inserted entry, same as [add] / [Player.open].
  ///
  /// When [index] is the currently-playing entry, the swap is routed
  /// through `playlist-next` so it inherits mpv's prefetch-driven
  /// transition path instead of stopping and restarting playback.
  /// (Audible only with `--prefetch-playlist=yes`, the default for
  /// this build.)
  Future<void> replace(int index, Media media) async {
    _checkNotDisposed();
    await _ready;
    _validateLoadOptions(media);
    _mediaCache[media.uri] = media;
    final tls = _tlsBundleReady;
    final resolved = await resolveUri(media.uri);
    await tls;
    if (_disposed) {
      await resolved.dispose?.call();
      return;
    }
    _mediaCache[resolved.uri] = media;
    final currentPos = using((arena) {
      final ptr = _lib.mpvGetPropertyString(
        _handle,
        'playlist-pos'.toNativeUtf8(allocator: arena),
      );
      if (ptr == nullptr) return -1;
      final s = ptr.cast<Utf8>().toDartString();
      _lib.mpvFree(ptr.cast());
      return int.tryParse(s) ?? -1;
    });
    final opts = _buildLoadfileOptions(media);
    void insertAt(int at) {
      if (opts.isEmpty) {
        _command(['loadfile', resolved.uri, 'insert-at', at.toString()]);
      } else {
        // 4th-arg options require an explicit index argument (mpv 0.38+).
        _command(['loadfile', resolved.uri, 'insert-at', at.toString(), opts]);
      }
    }

    if (currentPos == index) {
      // Currently-playing entry: insert the replacement right after
      // the active position, then advance — mpv's playlist-prefetch
      // (already triggered by the insert) makes the cross-fade
      // gapless for typical music files. Finally drop the original.
      insertAt(index + 1);
      _command(['playlist-next', 'force']);
      _command(['playlist-remove', index.toString()]);
    } else {
      _command(['playlist-remove', index.toString()]);
      insertAt(index);
    }
  }

  /// Clears the playlist, **including the currently-playing track**.
  /// Playback stops; `state.playlist.items` becomes empty and
  /// `state.playing` becomes `false`. Use [remove] for selective
  /// clearing that keeps the active entry alive.
  Future<void> clearPlaylist() async {
    _checkNotDisposed();
    await _ready;
    _mediaCache.clear();
    // mpv's `playlist-clear` alone keeps the active entry; the
    // explicit `playlist-remove current` makes the call match the
    // method name.
    _command(['playlist-clear']);
    _command(['playlist-remove', 'current']);
  }

  /// Sets the playlist repeat mode.
  ///
  /// Backed by two mpv properties (`loop-file` + `loop-playlist`); if
  /// the second write fails the first is rolled back so the consumer
  /// never observes a half-applied loop mode.
  Future<void> setLoop(Loop loop) async {
    _checkNotDisposed();
    await _ready;
    String loopFile(Loop l) => l == Loop.file ? 'inf' : 'no';
    String loopPlaylist(Loop l) => l == Loop.playlist ? 'inf' : 'no';
    final previous = state.loop;
    try {
      _prop('loop-file', loopFile(loop));
      try {
        _prop('loop-playlist', loopPlaylist(loop));
      } catch (_) {
        _propRc('loop-file', loopFile(previous));
        rethrow;
      }
    } catch (_) {
      rethrow;
    }
    // Optimistic update — `state.loop` reflects the requested mode
    // without waiting for the two underlying observers to round-trip.
    _updateField((s) => s.copyWith(loop: loop), _loop, loop);
  }

  /// Enables or disables shuffle mode.
  Future<void> setShuffle(bool shuffle) async {
    _checkNotDisposed();
    await _ready;
    _prop('shuffle', shuffle ? 'yes' : 'no');
    if (shuffle) {
      _command(['playlist-shuffle']);
    } else {
      _command(['playlist-unshuffle']);
    }
    _updateField(
        (s) => s.copyWith(shuffle: shuffle), _reactives.shuffle, shuffle,);
  }

  /// Enables or disables background prefetch of the next playlist item.
  ///
  /// When enabled, mpv opens the demuxer for the next track before the
  /// current one finishes, so playback continues without an opening-thread
  /// stall on file boundaries. Observe progress via
  /// [PlayerStream.prefetchState].
  Future<void> setPrefetchPlaylist(bool enabled) async {
    _checkNotDisposed();
    await _ready;
    _prop('prefetch-playlist', enabled ? 'yes' : 'no');
    _updateField((s) => s.copyWith(prefetchPlaylist: enabled),
        _reactives.prefetchPlaylist, enabled,);
  }
}

// Runtime catalog of mpv commands + properties built from the live
// engine's introspection (`command-list`, `property-list`, lazy
// `option-info/<name>`, `audio-device-list`). Static curated
// descriptions overlay the runtime data so common entries read in
// plain English; everything else falls back to the bare name.

/// One entry in mpv's `command-list` array.
class CmdSpec {
  final String name;
  final List<CmdArg> args;
  final bool vararg;
  final String? description;

  const CmdSpec({
    required this.name,
    required this.args,
    required this.vararg,
    this.description,
  });

  /// Pretty-printable arg syntax, e.g. `<name> <value> [<flags>]`.
  String get argSyntax {
    if (args.isEmpty) return vararg ? '...' : '';
    final parts = args.map((a) {
      final brackets = a.optional;
      return brackets ? '[<${a.name}>]' : '<${a.name}>';
    }).toList();
    if (vararg) parts.add('...');
    return parts.join(' ');
  }
}

class CmdArg {
  final String name;
  final String type;
  final bool optional;
  const CmdArg({required this.name, required this.type, required this.optional});
}

/// One entry in mpv's `property-list`. Names only — types must come
/// from a separate `option-info/<name>` lookup (and only for real
/// options, not computed properties).
class PropSpec {
  final String name;
  final String? description;
  const PropSpec({required this.name, this.description});
}

/// Result of `option-info/<name>`. Populated only for properties
/// that map to a real m_option (most settable properties); computed
/// state-only properties (`time-pos`, `audio-params`, `playlist`,
/// `track-list`, ...) return `null`.
class OptionInfo {
  /// mpv type string: `Integer`, `Float`, `Double`, `Flag`, `Choice`,
  /// `String`, `Object settings list`, `Color`, `Time`, ...
  final String type;
  /// Allowed values for `Choice` and `Object settings list` types.
  final List<String>? choices;
  /// Numeric range for `Integer` / `Float` / `Double` types.
  final num? min;
  final num? max;
  /// mpv's documented default value (typed).
  final dynamic defaultValue;

  const OptionInfo({
    required this.type,
    this.choices,
    this.min,
    this.max,
    this.defaultValue,
  });

  static OptionInfo? fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String) return null;
    final rawChoices = json['choices'];
    return OptionInfo(
      type: type,
      choices: rawChoices is List
          ? rawChoices.whereType<String>().toList(growable: false)
          : null,
      min: json['min'] is num ? json['min'] as num : null,
      max: json['max'] is num ? json['max'] as num : null,
      defaultValue: json['default-value'],
    );
  }
}

/// One entry in mpv's `audio-device-list`. Lists real OS audio output
/// devices the user can route to via `set audio-device <name>`.
class AudioDevice {
  final String name;
  final String description;
  const AudioDevice({required this.name, required this.description});
}

// ─── Curated descriptions ─────────────────────────────────────────────
//
// Hand-written one-liners for the commands and properties a user
// typically reaches for. Anything outside these maps still appears
// in the autocomplete (it's all fetched at runtime from mpv) — it
// just falls back to displaying just the name + arg syntax.

const Map<String, String> curatedCommandDescriptions = <String, String>{
  // Property mutators
  'set': 'set property to value',
  'cycle': 'cycle property through values',
  'add': 'add to numeric property',
  'multiply': 'multiply numeric property',
  'cycle-values': 'cycle property through given values',
  'change-list': 'modify a list option',
  // Seek / playback
  'seek': 'seek by amount',
  'revert-seek': 'revert last seek',
  'frame-step': 'step one frame forward',
  'frame-back-step': 'step one frame back',
  // OSD / text
  'print-text': 'print to terminal',
  'show-text': 'show OSD text',
  'show-progress': 'show progress bar',
  'osd': 'cycle OSD level',
  'expand-text': 'expand mpv text expansion',
  'expand-path': 'expand path with mpv conventions',
  // Lifecycle
  'stop': 'stop playback (keep playlist)',
  'quit': 'quit mpv',
  'quit-watch-later': 'quit and save resume state',
  'write-watch-later-config': 'save resume state',
  'delete-watch-later-config': 'delete resume state',
  // Files
  'loadfile': 'open file or URL',
  'loadlist': 'load playlist file',
  // Playlist
  'playlist-next': 'next track',
  'playlist-prev': 'previous track',
  'playlist-clear': 'clear playlist except current',
  'playlist-remove': 'remove playlist entry',
  'playlist-move': 'move playlist entry',
  'playlist-shuffle': 'shuffle playlist',
  'playlist-unshuffle': 'restore playlist order',
  'playlist-play-index': 'jump to playlist index',
  // Tracks
  'audio-add': 'add external audio track',
  'audio-remove': 'remove audio track',
  'audio-reload': 'reload audio track',
  'sub-add': 'add subtitle file',
  'sub-remove': 'remove subtitle',
  'sub-reload': 'reload subtitle',
  'sub-step': 'step to next/prev subtitle',
  'sub-seek': 'seek to next/prev subtitle',
  // Filters
  'af': 'modify audio filter chain',
  'vf': 'modify video filter chain',
  'af-command': 'send command to audio filter',
  'vf-command': 'send command to video filter',
  // Loops
  'ab-loop': 'toggle A-B loop',
  'drop-buffers': 'drop buffered audio/video',
  // Input
  'mouse': 'simulate mouse event',
  'keypress': 'simulate key press',
  'keydown': 'simulate key down',
  'keyup': 'simulate key up',
  'keybind': 'bind key to command',
  'enable-section': 'enable input section',
  'disable-section': 'disable input section',
  // Screenshot
  'screenshot': 'take screenshot',
  'screenshot-to-file': 'screenshot to specific path',
  'screenshot-raw': 'screenshot to memory',
  // Scripts / overlay
  'script-binding': 'invoke scripted binding',
  'script-message': 'broadcast message to scripts',
  'script-message-to': 'send message to named script',
  'overlay-add': 'add OSD overlay',
  'overlay-remove': 'remove OSD overlay',
  // External
  'run': 'run external command (fire-and-forget)',
  'subprocess': 'run subprocess (advanced)',
};

const Map<String, String> curatedPropertyDescriptions = <String, String>{
  // ── Audio ────────────────────────────────────────────────────────
  'volume': 'audio volume (0..volume-max)',
  'volume-max': 'maximum allowed volume %',
  'volume-gain': 'extra gain in dB',
  'mute': 'mute audio (yes/no)',
  'audio-delay': 'audio sync offset in seconds',
  'audio-device': 'output device name',
  'audio-device-list': 'available output devices',
  'audio-format': 'sample format (s16/s32/float/...)',
  'audio-channels': 'channel layout',
  'audio-samplerate': 'output sample rate',
  'aid': 'selected audio track id',
  'audio-pid': 'audio packet id',
  'audio-codec': 'audio codec name',
  'audio-codec-name': 'short codec name',
  'audio-bitrate': 'audio bitrate in bps',
  'audio-params': 'live audio params',
  'audio-out-params': 'AO output params',
  'audio-out-detected-device': 'detected output device',
  'af': 'audio filter chain',
  'pitch': 'pitch in semitones',
  'speed': 'playback speed (0.01..100)',
  'replaygain': 'replaygain mode',
  'replaygain-fallback': 'fallback gain in dB',
  'replaygain-preamp': 'preamp in dB',
  'replaygain-clip': 'clip handling',
  'replaygain-track-peak': 'track peak (read-only)',
  'replaygain-track-gain': 'track gain dB (read-only)',
  // ── Playback ─────────────────────────────────────────────────────
  'pause': 'pause playback (yes/no)',
  'time-pos': 'current position (seconds)',
  'time-remaining': 'remaining time',
  'duration': 'total duration in seconds',
  'percent-pos': 'position as 0..100',
  'eof-reached': 'end-of-file flag',
  'core-idle': 'engine idle state',
  'idle-active': 'no file loaded',
  'paused-for-cache': 'paused due to buffering',
  'seekable': 'is current file seekable',
  'partially-seekable': 'partially seekable (e.g. live)',
  'playback-time': 'playback PTS',
  'playback-abort': 'aborting playback',
  // ── Loop ─────────────────────────────────────────────────────────
  'loop-file': 'loop current file',
  'loop-playlist': 'loop playlist',
  'ab-loop-a': 'A-B loop start time',
  'ab-loop-b': 'A-B loop end time',
  'ab-loop-count': 'A-B loop iterations remaining',
  // ── Playlist ─────────────────────────────────────────────────────
  'playlist': 'current playlist',
  'playlist-pos': 'current playlist position (0-indexed)',
  'playlist-pos-1': 'current playlist position (1-indexed)',
  'playlist-count': 'playlist size',
  'playlist-current-pos': 'currently-playing position',
  'playlist-shuffle': 'shuffle on/off',
  'shuffle': 'shuffle (alias)',
  // ── File ─────────────────────────────────────────────────────────
  'filename': 'current file name',
  'filename/no-ext': 'current file name without extension',
  'media-title': 'current media title',
  'path': 'full path',
  'stream-path': 'mpv stream path',
  'stream-open-filename': 'opened file (post hook redirect)',
  'file-size': 'file size in bytes',
  'file-format': 'detected container format',
  'duration/full': 'duration with fractional precision',
  'metadata': 'tag metadata',
  'chapter': 'current chapter index',
  'chapters': 'chapter count',
  'chapter-list': 'list of chapters',
  // ── Demuxer / cache ──────────────────────────────────────────────
  'cache-size': 'cache size in MB',
  'cache-secs': 'cache target seconds',
  'demuxer': 'active demuxer',
  'demuxer-cache-state': 'demuxer cache state',
  'demuxer-via-network': 'streaming via network',
  // ── Network ──────────────────────────────────────────────────────
  'tls-ca-file': 'custom CA bundle path',
  'network-timeout': 'network timeout in seconds',
  'user-agent': 'HTTP User-Agent',
  'http-header-fields': 'HTTP request headers',
  'referrer': 'HTTP Referer',
  // ── Logging ──────────────────────────────────────────────────────
  'msg-level': 'log filter (subsystem=level, ...)',
  'log-file': 'mpv log to file path',
  // ── Patches shipped with mpv_audio_kit ──────────────────────────
  'pcm-tap-frame': 'live PCM frame from chain output',
  'audio-output-state': 'AO state (active/closed/failed)',
  'analyzer-taps': 'active per-filter taps (CSV)',
  'audio-tap-frames': 'per-filter PCM tap frames',
  'embedded-cover-art-data': 'cover art bytes',
  'embedded-cover-art-mime': 'cover art mime type',
  'prefetch-state': 'prefetch lifecycle state',
};

/// Commands whose 2nd argument is a property name. The autocomplete
/// switches from "command list" to "property list" after the user
/// types one of these followed by a space.
const Set<String> propertyTakingCommands = {
  'set',
  'cycle',
  'add',
  'multiply',
  'change-list',
};

/// Commands where the 3rd argument is a value for the given property.
/// Currently only `set` — the others are operators (cycle / add /
/// multiply / change-list) where the 3rd token is freeform.
const Set<String> valueTakingCommands = {
  'set',
};

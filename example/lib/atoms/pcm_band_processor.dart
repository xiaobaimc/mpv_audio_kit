import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Per-stream FFT processor for the pro filter editors.
///
/// Implements the same overlap-add Hann pattern used by every pro
/// spectrum analyser (FabFilter Pro-Q, Voxengo SPAN, the JUCE
/// tutorial implementation, …): a rolling sample ring of length
/// [fftSize] is fed by each incoming [PcmFrame], and a fresh FFT is
/// computed every [hopSize] = `fftSize / 4` samples. With Hann
/// windowing at 75 % overlap, the COLA condition is satisfied, the
/// effective output rate is 4× the natural frame rate, and the
/// asymmetric EMA on the bands picks up four times as many update
/// points per unit of input audio — visually continuous instead of
/// stepping at the polling cadence.
///
/// Hold one instance per stream; call [process] on every incoming
/// [PcmFrame] and pass the returned bands snapshot to
/// [SpectrumCurve.paintOn]. The instance owns its scratch — calls
/// stay GC-quiet under steady-state playback.
class PcmBandProcessor {
  PcmBandProcessor({
    this.fftSize = 1024,
    int? hopSize,
    this.bandCount = 96,
    this.bandLowHz = 30.0,
    this.bandHighHz = 18000.0,
    this.minDb = -70.0,
    this.maxDb = 0.0,
    this.attack = 0.5,
    this.release = 0.1,
  })  : assert((fftSize & (fftSize - 1)) == 0,
            'fftSize must be a power of two'),
        hopSize = hopSize ?? (fftSize ~/ 4),
        _fft = FFT(fftSize),
        _ring = Float64List(fftSize),
        _windowed = Float64List(fftSize),
        _buffer = Float64x2List(fftSize),
        _window = _hann(fftSize),
        _smoothed = Float32List(bandCount);

  final int fftSize;
  final int hopSize;
  final int bandCount;
  final double bandLowHz;
  final double bandHighHz;
  final double minDb;
  final double maxDb;
  final double attack;
  final double release;

  final FFT _fft;
  // Rolling sample ring — last [fftSize] mono samples written, with
  // [_ringWrite] pointing at the next slot.
  final Float64List _ring;
  int _ringWrite = 0;
  int _samplesInRing = 0;
  int _samplesUntilNextHop = 0;

  final Float64List _windowed;     // ring × hann, fed into the FFT
  final Float64x2List _buffer;     // FFT in-place complex buffer
  final Float32List _window;
  final Float32List _smoothed;

  Int32List? _bandStartBin;
  Int32List? _bandEndBin;
  int _lastSampleRate = 0;
  int _lastChannels = 0;

  /// Returns a snapshot of the latest log-spaced bands. Reuses
  /// internal scratch — the returned [Float32List] is a fresh copy
  /// safe to hold across further calls.
  Float32List process(PcmFrame frame) {
    final samples = frame.samples;
    final channels = frame.channels;
    final sampleRate = frame.sampleRate;
    if (samples.isEmpty || channels <= 0 || sampleRate <= 0) {
      return Float32List.fromList(_smoothed);
    }

    final samplesPerChannel = samples.length ~/ channels;
    if (samplesPerChannel <= 0) return Float32List.fromList(_smoothed);

    if (sampleRate != _lastSampleRate || channels != _lastChannels) {
      _lastSampleRate = sampleRate;
      _lastChannels = channels;
      _bandStartBin = null;
    }

    // Push every input sample (mono-mixed) through the rolling ring
    // and fire an overlap-add FFT every [hopSize] samples once the
    // ring has been filled at least once.
    final invChannels = channels == 1 ? 1.0 : 1.0 / channels;
    if (channels == 1) {
      for (var i = 0; i < samplesPerChannel; i++) {
        _push(samples[i].toDouble());
      }
    } else {
      for (var i = 0; i < samplesPerChannel; i++) {
        var sum = 0.0;
        final base = i * channels;
        for (var c = 0; c < channels; c++) {
          sum += samples[base + c];
        }
        _push(sum * invChannels);
      }
    }

    return Float32List.fromList(_smoothed);
  }

  void _push(double mono) {
    _ring[_ringWrite] = mono;
    _ringWrite = (_ringWrite + 1) % fftSize;
    if (_samplesInRing < fftSize) _samplesInRing++;
    _samplesUntilNextHop--;
    if (_samplesUntilNextHop <= 0 && _samplesInRing >= fftSize) {
      _samplesUntilNextHop = hopSize;
      _runFft();
    }
  }

  void _runFft() {
    // Read the ring in time order: oldest sample is at [_ringWrite],
    // newest is at [(_ringWrite − 1) mod fftSize]. Apply Hann while
    // copying so the next loop is one mul + one store per sample.
    final start = _ringWrite;
    for (var i = 0; i < fftSize; i++) {
      final src = (start + i) % fftSize;
      _windowed[i] = _ring[src] * _window[i];
    }

    for (var i = 0; i < fftSize; i++) {
      _buffer[i] = Float64x2(_windowed[i], 0);
    }
    _fft.inPlaceFft(_buffer);

    final binCount = fftSize ~/ 2;
    if (_bandStartBin == null) {
      _computeBandMapping(_lastSampleRate, fftSize, binCount);
    }

    final dbRange = maxDb - minDb;
    if (dbRange <= 0) return;

    final start2 = _bandStartBin!;
    final end2 = _bandEndBin!;
    for (var b = 0; b < bandCount; b++) {
      final s = start2[b];
      final e = end2[b];
      var sum = 0.0;
      final count = e - s;
      if (count > 0) {
        for (var i = s; i < e; i++) {
          final c = _buffer[i];
          final power = c.x * c.x + c.y * c.y;
          final db = 10 * (math.log(power + 1e-12) / math.ln10);
          var n = (db - minDb) / dbRange;
          if (n < 0) n = 0;
          if (n > 1) n = 1;
          sum += n;
        }
        sum /= count;
      }
      final prev = _smoothed[b];
      final alpha = sum > prev ? attack : release;
      _smoothed[b] = prev + alpha * (sum - prev);
    }
  }

  void _computeBandMapping(int sampleRate, int fftSize, int binCount) {
    final low = math.max(bandLowHz, 1.0);
    final nyquist = sampleRate / 2.0;
    final high = math.min(bandHighHz, nyquist);
    final start = Int32List(bandCount);
    final end = Int32List(bandCount);
    if (high <= low || binCount <= 0) {
      _bandStartBin = start;
      _bandEndBin = end;
      return;
    }
    final binHz = sampleRate / fftSize;
    final ratio = math.pow(high / low, 1 / bandCount).toDouble();
    for (var b = 0; b < bandCount; b++) {
      final lowHz = low * math.pow(ratio, b);
      final highHz = low * math.pow(ratio, b + 1);
      var s = (lowHz / binHz).floor();
      var e = (highHz / binHz).ceil();
      if (s < 0) s = 0;
      if (s >= binCount) s = binCount - 1;
      if (e <= s) e = s + 1;
      if (e > binCount) e = binCount;
      start[b] = s;
      end[b] = e;
    }
    _bandStartBin = start;
    _bandEndBin = end;
  }

  /// Hann window — same shape used by the lib's spectrum pipeline.
  /// Combined with 75 % overlap (`hopSize = fftSize / 4`) it
  /// satisfies the COLA criterion (`Σ w[i + k·hop]² = const`), so
  /// successive overlap-add FFTs reconstruct the input cleanly and
  /// the per-band visual EMA picks up four times as many updates
  /// per unit of input audio.
  static Float32List _hann(int n) {
    final w = Float32List(n);
    for (var i = 0; i < n; i++) {
      w[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
    }
    return w;
  }
}

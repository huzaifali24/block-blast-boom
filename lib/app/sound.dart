import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'music.dart';

/// The sound cues the game needs.
enum SoundEffect { pick, place, clear, combo, gameOver, tap, coin }

/// Plays short effects that are synthesized as WAV bytes once at startup,
/// so the game has punchy audio without shipping any sound files.
class Sound {
  Sound._();
  static final instance = Sound._();

  bool enabled = true;

  final Map<SoundEffect, AudioPlayer> _players = {};
  final Map<SoundEffect, List<Uint8List>> _clips = {};

  /// How many pitch/size variants each effect has:
  /// place — 3 slight pitch variations so repeats don't grate;
  /// clear — one step higher per combo level (0 = first clear);
  /// combo — bigger flourish per extra line (0 = 2 lines ... 4 = 6+).
  static int variantsOf(SoundEffect fx) => switch (fx) {
        SoundEffect.place => 3,
        SoundEffect.clear => 8,
        SoundEffect.combo => 5,
        _ => 1,
      };

  /// Renders one variant as WAV bytes (exposed for tests).
  static Uint8List renderClip(SoundEffect fx, int variant) =>
      _Synth.build(fx, variant);

  Future<void> init() async {
    for (final fx in SoundEffect.values) {
      _clips[fx] = [
        for (var v = 0; v < variantsOf(fx); v++) _Synth.build(fx, v),
      ];
      try {
        _players[fx] = AudioPlayer()
          ..setAudioContext(gameAudioContext())
          ..setReleaseMode(ReleaseMode.stop);
      } catch (_) {
        // No audio plugin (tests) — stay silent.
      }
    }
  }

  /// Plays [fx]; [variant] is clamped to what exists.
  Future<void> play(SoundEffect fx, {int variant = 0}) async {
    if (!enabled) return;
    final player = _players[fx];
    final all = _clips[fx];
    final clip =
        all == null || all.isEmpty ? null : all[variant.clamp(0, all.length - 1)];
    if (player == null || clip == null) return;
    try {
      await player.stop();
      await player.play(BytesSource(clip, mimeType: 'audio/wav'));
    } catch (_) {
      // The platform has no audio output (CI, some emulators) — play silently.
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
  }
}

/// A tiny additive synth: each effect is a list of notes mixed into one
/// mono 16-bit buffer.
class _Synth {
  static const _rate = 22050;

  static double _semis(num n) => math.pow(2, n / 12).toDouble();

  static Uint8List build(SoundEffect fx, [int variant = 0]) {
    final v = variant;
    switch (fx) {
      case SoundEffect.pick:
        return _render(.07, [_Note(0, .06, 520, 680, .35, wave: _square)]);
      case SoundEffect.place:
        final k = const [1.0, 1.08, .93][v % 3];
        return _render(.12, [
          _Note(0, .11, 190 * k, 110 * k, .8),
          _Note(0, .02, 1800, 900, .18, wave: _noise),
        ]);
      case SoundEffect.clear:
        // Each combo step climbs a whole tone.
        final k = _semis(v * 2);
        return _render(.34, [
          for (var i = 0; i < 3; i++)
            _Note(i * .06, .2, [784.0, 988.0, 1319.0][i] * k, null, .42,
                wave: _tri),
          _Note(0, .25, 3000, 600, .08, wave: _noise),
        ]);
      case SoundEffect.combo:
        // More lines: a longer, higher run, a sparkle and (3+ lines) a boom.
        const run = [784.0, 988.0, 1175.0, 1568.0, 1976.0, 2349.0, 2637.0, 3136.0, 3520.0];
        final k = _semis(v);
        final notes = 5 + v;
        return _render(.5 + v * .07, [
          for (var i = 0; i < notes; i++)
            _Note(i * .045, .24, run[i] * k, null, .36, wave: _tri),
          _Note(.22 + v * .04, .3, 2637 * k, null, .16),
          _Note(0, .3 + v * .05, 4000, 800, .08 + v * .015, wave: _noise),
          if (v >= 1) _Note(0, .35 + v * .05, 110, 38, .5 + v * .05),
        ]);
      case SoundEffect.gameOver:
        return _render(.95, [
          for (var i = 0; i < 4; i++)
            _Note(i * .17, .3, [523.0, 440.0, 349.0, 262.0][i], null, .42,
                wave: _tri),
        ]);
      case SoundEffect.tap:
        return _render(.05, [_Note(0, .04, 1100, 900, .3, wave: _square)]);
      case SoundEffect.coin:
        return _render(.32, [
          _Note(0, .08, 1319, null, .35, wave: _square),
          _Note(.07, .22, 1976, null, .35, wave: _square),
        ]);
    }
  }

  static double _sine(double phase) => math.sin(phase * 2 * math.pi);
  static double _tri(double phase) => 1 - 4 * ((phase % 1) - .5).abs();
  static double _square(double phase) => (phase % 1) < .5 ? .6 : -.6;
  static final _rng = math.Random(7);
  static double _noise(double _) => _rng.nextDouble() * 2 - 1;

  static Uint8List _render(double seconds, List<_Note> notes) {
    final n = (seconds * _rate).round();
    final mix = Float64List(n);
    for (final note in notes) {
      final start = (note.start * _rate).round();
      final len = (note.length * _rate).round();
      var phase = 0.0;
      for (var i = 0; i < len && start + i < n; i++) {
        final p = i / len;
        final f = note.to == null ? note.from : note.from + (note.to! - note.from) * p;
        phase += f / _rate;
        // Fast attack, exponential decay.
        final env = math.min(1.0, i / (_rate * .004)) * math.pow(1 - p, 2.2);
        mix[start + i] += note.wave(phase) * note.gain * env;
      }
    }
    final data = ByteData(44 + n * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = (mix[i].clamp(-1.0, 1.0) * 32000).round();
      data.setInt16(44 + i * 2, v, Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

class _Note {
  const _Note(this.start, this.length, this.from, this.to, this.gain,
      {this.wave = _Synth._sine});
  final double start;
  final double length;
  final double from;
  final double? to;
  final double gain;
  final double Function(double phase) wave;
}

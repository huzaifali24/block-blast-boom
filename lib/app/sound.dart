import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// The sound cues the game needs.
enum SoundEffect { pick, place, clear, combo, gameOver, tap, coin }

/// Plays short effects that are synthesized as WAV bytes once at startup,
/// so the game has punchy audio without shipping any sound files.
class Sound {
  Sound._();
  static final instance = Sound._();

  bool enabled = true;

  final Map<SoundEffect, AudioPlayer> _players = {};
  final Map<SoundEffect, Uint8List> _clips = {};

  Future<void> init() async {
    for (final fx in SoundEffect.values) {
      _clips[fx] = _Synth.build(fx);
      try {
        _players[fx] = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      } catch (_) {
        // No audio plugin (tests) — stay silent.
      }
    }
  }

  Future<void> play(SoundEffect fx) async {
    if (!enabled) return;
    final player = _players[fx];
    final clip = _clips[fx];
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

  static Uint8List build(SoundEffect fx) {
    switch (fx) {
      case SoundEffect.pick:
        return _render(.07, [_Note(0, .06, 520, 680, .35, wave: _square)]);
      case SoundEffect.place:
        return _render(.12, [
          _Note(0, .11, 190, 110, .8),
          _Note(0, .02, 1800, 900, .18, wave: _noise),
        ]);
      case SoundEffect.clear:
        return _render(.34, [
          for (var i = 0; i < 3; i++)
            _Note(i * .06, .2, [784.0, 988.0, 1319.0][i], null, .42, wave: _tri),
          _Note(0, .25, 3000, 600, .08, wave: _noise),
        ]);
      case SoundEffect.combo:
        return _render(.5, [
          for (var i = 0; i < 5; i++)
            _Note(i * .05, .24, [784.0, 988.0, 1175.0, 1568.0, 1976.0][i], null,
                .38,
                wave: _tri),
          _Note(.22, .26, 2637, null, .16),
          _Note(0, .3, 4000, 800, .08, wave: _noise),
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

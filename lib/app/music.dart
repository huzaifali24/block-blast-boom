import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Looping background music.
///
/// The track is an original chill loop composed in code by [MusicSynth]
/// (no audio files or licenses needed). It's rendered once on a background
/// isolate, cached as a WAV in the temp directory, and played on its own
/// player at a low volume so sound effects sit on top of it. It pauses
/// whenever the app leaves the foreground.
class Music with WidgetsBindingObserver {
  Music._();
  static final instance = Music._();

  static const _volume = .38;
  static const _file = 'block_boom_music_v1.wav';

  bool _enabled = true;
  bool _foreground = true;
  bool _ducked = false;
  AudioPlayer? _player;

  bool get enabled => _enabled;

  /// Whether the track is loaded and playing right now (for diagnostics).
  bool get isPlaying => _player?.state == PlayerState.playing;

  Future<void> init({required bool enabled}) async {
    _enabled = enabled;
    WidgetsBinding.instance.addObserver(this);
    try {
      final file = File('${Directory.systemTemp.path}/$_file');
      if (!file.existsSync() || file.lengthSync() < 1000) {
        final bytes = await Isolate.run(MusicSynth.render);
        await file.writeAsBytes(bytes, flush: true);
      }
      final p = AudioPlayer(playerId: 'music');
      await p.setAudioContext(gameAudioContext(music: true));
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(_volume);
      await p.setSource(DeviceFileSource(file.path, mimeType: 'audio/wav'));
      _player = p;
      await _sync();
    } catch (e) {
      debugPrint('Music unavailable: $e');
    }
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    await _sync();
  }

  /// Lowers the music (e.g. under the game-over sting) or restores it.
  Future<void> duck(bool on) async {
    if (_ducked == on) return;
    _ducked = on;
    await _player?.setVolume(on ? _volume * .3 : _volume);
  }

  Future<void> _sync() async {
    final p = _player;
    if (p == null) return;
    try {
      if (_enabled && _foreground) {
        if (p.state != PlayerState.playing) await p.resume();
      } else if (p.state == PlayerState.playing) {
        await p.pause();
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` covers the notification shade and dialogs: keep playing.
    _foreground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _sync();
  }
}

/// Audio settings for game sounds: tagged as game audio and *not* taking
/// audio focus, so the game never pauses the player's own music or
/// podcast — it simply mixes with it.
AudioContext gameAudioContext({bool music = false}) => AudioContext(
      android: AudioContextAndroid(
        usageType: AndroidUsageType.game,
        contentType:
            music ? AndroidContentType.music : AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    );

/// Composes and renders the background loop.
///
/// 16 bars at 100 BPM in A minor (~38 s):
///   A section: Am F C G x2 — warm pad, plucked arpeggio with echo, bass;
///              drums fade in on the second pass.
///   B section: F G Em Am F G C G — adds a soft lead melody.
/// Every note is written with wrap-around, so release tails from the last
/// bar spill into the first and the loop has no seam.
class MusicSynth {
  MusicSynth._();

  static const rate = 32000;
  static const bpm = 100.0;
  static const bars = 16;
  static double get beat => 60 / bpm;
  static double get barLen => beat * 4;
  static int get length => (barLen * bars * rate).round();

  // Chords: (bass midi, voicing).
  static const _am = (45, [57, 60, 64]);
  static const _f = (41, [57, 60, 65]);
  static const _c = (48, [55, 60, 64]);
  static const _g = (43, [55, 59, 62]);
  static const _em = (40, [55, 59, 64]);

  static final _progression = [
    _am, _f, _c, _g, _am, _f, _c, _g, //
    _f, _g, _em, _am, _f, _g, _c, _g,
  ];

  // Lead melody for the B section: (bar, beat, beats, midi).
  static const _melody = [
    (8, 0.0, 1.5, 72), (8, 1.5, .5, 74), (8, 2.0, 2.0, 76),
    (9, 0.0, 1.5, 74), (9, 1.5, .5, 72), (9, 2.0, 2.0, 71),
    (10, 0.0, 1.0, 67), (10, 1.0, 1.0, 71), (10, 2.0, 2.0, 74),
    (11, 0.0, 3.0, 72), (11, 3.0, 1.0, 71),
    (12, 0.0, 1.5, 72), (12, 1.5, .5, 74), (12, 2.0, 2.0, 76),
    (13, 0.0, 1.0, 79), (13, 1.0, 1.0, 77), (13, 2.0, 2.0, 74),
    (14, 0.0, 2.0, 76), (14, 2.0, 1.0, 74), (14, 3.0, 1.0, 72),
    (15, 0.0, 2.0, 71), (15, 2.0, 2.0, 74),
  ];

  static double _hz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

  /// Renders the loop to a mono 16-bit WAV.
  static Uint8List render() {
    final n = length;
    final mix = Float64List(n);
    final arp = Float64List(n);
    final rng = math.Random(3);

    void note(Float64List buf, double start, double dur, double hz, double gain,
        double Function(double phase, double t) voice,
        {double attack = .005, double release = .25}) {
      final s0 = (start * rate).round();
      final len = ((dur + release) * rate).round();
      var phase = 0.0;
      for (var i = 0; i < len; i++) {
        final t = i / rate;
        phase += hz / rate;
        final env = t < attack
            ? t / attack
            : t < dur
                ? 1.0
                : math.max(0.0, 1 - (t - dur) / release);
        // The release ramps to exactly zero, so note ends never click.
        buf[(s0 + i) % n] += voice(phase, t) * gain * env;
      }
    }

    double sine(double p) => math.sin(p * 2 * math.pi);

    // Warm pad: detuned sine stack with a slow swell.
    double pad(double p, double t) =>
        (sine(p) + .35 * sine(p * 2.003) + .18 * sine(p * 2.997)) *
        (.85 + .15 * sine(t * .4));

    // Plucked bell for the arpeggio.
    double pluck(double p, double t) =>
        (sine(p) + .4 * sine(p * 2) + .12 * sine(p * 4.01)) * math.exp(-t * 7);

    // Round bass.
    double bass(double p, double t) =>
        (sine(p) + .3 * sine(p * 2)) * math.exp(-t * 2.2);

    // Soft lead.
    double lead(double p, double t) =>
        (sine(p) + .25 * sine(p * 2) + .08 * sine(p * 3)) *
        (1 + .03 * sine(t * 5.5)); // gentle vibrato-ish shimmer

    for (var bar = 0; bar < bars; bar++) {
      final (root, chord) = _progression[bar];
      final t0 = bar * barLen;

      // Pad.
      for (final m in chord) {
        note(mix, t0, barLen, _hz(m), .075, pad, attack: .35, release: .9);
      }

      // Bass: beat 1, the "and" of 2, beat 3.
      for (final (b, d) in const [(0.0, 1.2), (1.5, .45), (2.0, 1.6)]) {
        note(mix, t0 + b * beat, d * beat, _hz(root), .32, bass, release: .2);
      }

      // Arpeggio (eighths), pattern varies by section.
      final tones = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[0] + 24];
      final pattern = bar < 8
          ? const [0, 1, 2, 3, 2, 1, 0, 1]
          : const [0, 2, 1, 3, 0, 2, 3, 1];
      for (var k = 0; k < 8; k++) {
        note(arp, t0 + k * beat / 2, beat * .45, _hz(tones[pattern[k]]), .1,
            pluck, release: .3);
      }

      // Drums: hats only on the first pass, full kit afterwards.
      final full = bar >= 4;
      for (var k = 0; k < 8; k++) {
        final t = t0 + k * beat / 2;
        if (k.isOdd || full) _hat(mix, t, k.isOdd ? .05 : .03, rng);
      }
      if (full) {
        _kick(mix, t0, .42);
        _kick(mix, t0 + 2 * beat, .36);
        _snap(mix, t0 + beat, .07, rng);
        _snap(mix, t0 + 3 * beat, .07, rng);
      } else {
        _kick(mix, t0, .28);
      }
    }

    for (final (bar, b, d, m) in _melody) {
      note(mix, bar * barLen + b * beat, d * beat * .95, _hz(m), .11, lead,
          attack: .03, release: .35);
    }

    // Dotted-eighth echo on the arpeggio (circular, so the loop stays
    // seamless), then mix it in.
    final delay = (beat * .75 * rate).round();
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < n; i++) {
        arp[i] += arp[(i - delay + n) % n] * .32;
      }
    }
    for (var i = 0; i < n; i++) {
      mix[i] += arp[i] * .7;
    }

    // Normalize to a comfortable peak.
    var peak = 0.0;
    for (final v in mix) {
      peak = math.max(peak, v.abs());
    }
    final g = peak > 0 ? .85 / peak : 1.0;
    return _wav(mix, g);
  }

  static void _kick(Float64List buf, double start, double gain) {
    final n = buf.length;
    final s0 = (start * rate).round();
    var phase = 0.0;
    for (var i = 0; i < (.22 * rate).round(); i++) {
      final t = i / rate;
      final hz = 45 + 90 * math.exp(-t * 30);
      phase += hz / rate;
      buf[(s0 + i) % n] += math.sin(phase * 2 * math.pi) * gain * math.exp(-t * 14);
    }
  }

  static void _hat(Float64List buf, double start, double gain, math.Random rng) {
    final n = buf.length;
    final s0 = (start * rate).round();
    var prev = 0.0;
    for (var i = 0; i < (.05 * rate).round(); i++) {
      final t = i / rate;
      final white = rng.nextDouble() * 2 - 1;
      final hp = white - prev; // crude high-pass for a crisp tick
      prev = white;
      buf[(s0 + i) % n] += hp * gain * math.exp(-t * 90);
    }
  }

  static void _snap(Float64List buf, double start, double gain, math.Random rng) {
    final n = buf.length;
    final s0 = (start * rate).round();
    var lp = 0.0;
    for (var i = 0; i < (.12 * rate).round(); i++) {
      final t = i / rate;
      lp += ((rng.nextDouble() * 2 - 1) - lp) * .35; // soften the noise
      buf[(s0 + i) % n] +=
          (lp + .3 * math.sin(t * 2 * math.pi * 190)) * gain * math.exp(-t * 28);
    }
  }

  static Uint8List _wav(Float64List mix, double gain) {
    final n = mix.length;
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
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      data.setInt16(44 + i * 2, (mix[i] * gain * 32767).round().clamp(-32768, 32767),
          Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

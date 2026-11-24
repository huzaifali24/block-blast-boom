import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// The background tracks, each an original loop composed in code.
enum MusicTrack {
  /// Home and menus: slow and dreamy, no drums.
  menu(bpm: 84, transpose: -4, drums: 0, sixteenths: false, melody: true),

  /// Normal play: the chill groove.
  game(bpm: 100, transpose: 0, drums: 1, sixteenths: false, melody: true),

  /// When the board is crowded: faster, driving, urgent.
  tense(bpm: 124, transpose: 2, drums: 2, sixteenths: true, melody: false);

  const MusicTrack({
    required this.bpm,
    required this.transpose,
    required this.drums,
    required this.sixteenths,
    required this.melody,
  });

  final double bpm;

  /// Semitones relative to the A-minor home key.
  final int transpose;

  /// 0 = soft hats only, 1 = groove, 2 = driving four-on-the-floor.
  final int drums;

  /// Arpeggio in 16th notes instead of 8ths.
  final bool sixteenths;
  final bool melody;
}

/// Looping background music.
///
/// Three tracks ([MusicTrack]) are rendered once each on a background
/// isolate and cached as WAVs in the temp directory. Screens ask for a
/// track with [play]; switching crossfades on one player. Music sits at a
/// low volume under the sound effects and pauses whenever the app leaves
/// the foreground.
class Music with WidgetsBindingObserver {
  Music._();
  static final instance = Music._();

  static const _volume = .38;
  static String _fileFor(MusicTrack t) => 'block_boom_music_${t.name}_v2.wav';

  bool _enabled = true;
  bool _foreground = true;
  bool _ducked = false;
  AudioPlayer? _player;
  MusicTrack _wanted = MusicTrack.menu;
  MusicTrack? _loaded;
  final Map<MusicTrack, String> _ready = {};
  Future<void> _switching = Future.value();

  bool get enabled => _enabled;
  MusicTrack get track => _wanted;

  /// Whether the track is loaded and playing right now (for diagnostics).
  bool get isPlaying => _player?.state == PlayerState.playing;

  Future<void> init({required bool enabled}) async {
    _enabled = enabled;
    WidgetsBinding.instance.addObserver(this);
    try {
      final p = AudioPlayer(playerId: 'music');
      await p.setAudioContext(gameAudioContext(music: true));
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(_volume);
      _player = p;
    } catch (e) {
      debugPrint('Music unavailable: $e');
      return;
    }
    // Render the track needed now first, then the rest.
    final order = [_wanted, ...MusicTrack.values.where((t) => t != _wanted)];
    for (final t in order) {
      try {
        final file = File('${Directory.systemTemp.path}/${_fileFor(t)}');
        if (!file.existsSync() || file.lengthSync() < 1000) {
          final bytes = await _renderIsolated(t);
          await file.writeAsBytes(bytes, flush: true);
        }
        _ready[t] = file.path;
        if (t == _wanted) await _apply();
      } catch (e) {
        debugPrint('Music track ${t.name} unavailable: $e');
      }
    }
  }

  /// Switches to [t] (crossfading) once it's available.
  void play(MusicTrack t) {
    if (_wanted == t) return;
    _wanted = t;
    _switching = _switching.then((_) => _apply());
  }

  Future<void> _apply() async {
    final p = _player;
    final path = _ready[_wanted];
    if (p == null || path == null || _loaded == _wanted) {
      await _sync();
      return;
    }
    try {
      final playing = p.state == PlayerState.playing;
      if (playing) await _fade(p, _target, 0);
      await p.setSource(DeviceFileSource(path, mimeType: 'audio/wav'));
      _loaded = _wanted;
      await p.setVolume(0);
      await _sync();
      await _fade(p, 0, _target);
    } catch (e) {
      debugPrint('Music switch failed: $e');
    }
  }

  /// Renders off the UI thread. Static so the closure captures only the
  /// track (an instance closure would drag `this` into the isolate message,
  /// which can't be sent).
  static Future<Uint8List> _renderIsolated(MusicTrack t) =>
      Isolate.run(() => MusicSynth.render(t));

  double get _target => _ducked ? _volume * .3 : _volume;

  static Future<void> _fade(AudioPlayer p, double from, double to) async {
    const steps = 8;
    for (var i = 1; i <= steps; i++) {
      await p.setVolume(from + (to - from) * i / steps);
      await Future<void>.delayed(const Duration(milliseconds: 40));
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
    await _player?.setVolume(_target);
  }

  Future<void> _sync() async {
    final p = _player;
    if (p == null || _loaded == null) return;
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

/// Composes and renders the background loops.
///
/// Every track shares one 16-bar song, re-arranged per [MusicTrack]
/// (tempo, key, drums, arpeggio speed). The game arrangement is
/// 16 bars at 100 BPM in A minor (~38 s):
///   A section: Am F C G x2 — warm pad, plucked arpeggio with echo, bass;
///              drums fade in on the second pass.
///   B section: F G Em Am F G C G — adds a soft lead melody.
/// Every note is written with wrap-around, so release tails from the last
/// bar spill into the first and the loop has no seam.
class MusicSynth {
  MusicSynth._();

  static const rate = 32000;
  static const bars = 16;

  /// Samples in one loop of [t].
  static int lengthOf(MusicTrack t) => (60 / t.bpm * 4 * bars * rate).round();

  /// Samples in the game track (the default).
  static int get length => lengthOf(MusicTrack.game);

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

  /// Renders [track]'s loop to a mono 16-bit WAV.
  static Uint8List render([MusicTrack track = MusicTrack.game]) {
    final beat = 60 / track.bpm;
    final barLen = beat * 4;
    final n = lengthOf(track);
    final mix = Float64List(n);
    final arp = Float64List(n);
    final rng = math.Random(3);
    final k = track.transpose;
    double hz(num midi) => _hz(midi + k);

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

      // Pad (fuller when there are no drums).
      final padGain = track.drums == 0 ? .095 : .075;
      for (final m in chord) {
        note(mix, t0, barLen, hz(m), padGain, pad, attack: .35, release: .9);
      }

      // Bass: syncopated groove, or driving eighths when tense.
      final bassHits = track.drums == 2
          ? const [(0.0, .45), (.5, .45), (1.0, .45), (1.5, .45),
              (2.0, .45), (2.5, .45), (3.0, .45), (3.5, .45)]
          : const [(0.0, 1.2), (1.5, .45), (2.0, 1.6)];
      for (final (b, d) in bassHits) {
        note(mix, t0 + b * beat, d * beat, hz(root), track.drums == 2 ? .26 : .32,
            bass, release: .2);
      }

      // Arpeggio (eighths), pattern varies by section.
      final tones = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[0] + 24];
      final pattern = bar < 8
          ? const [0, 1, 2, 3, 2, 1, 0, 1]
          : const [0, 2, 1, 3, 0, 2, 3, 1];
      final steps = track.sixteenths ? 16 : 8;
      for (var s = 0; s < steps; s++) {
        note(arp, t0 + s * beat * 4 / steps, beat * 4 / steps * .9,
            hz(tones[pattern[s % 8]]), track.sixteenths ? .075 : .1, pluck,
            release: track.sixteenths ? .15 : .3);
      }

      switch (track.drums) {
        case 0:
          // Just a whisper of hats on the offbeats.
          for (var k = 0; k < 8; k++) {
            if (k.isOdd) _hat(mix, t0 + k * beat / 2, .025, rng);
          }
        case 1:
          // Hats only on the first pass, full kit afterwards.
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
        default:
          // Driving: kick on every beat, 16th hats, snaps on 2 and 4.
          for (var k = 0; k < 16; k++) {
            _hat(mix, t0 + k * beat / 4, k.isOdd ? .045 : .03, rng);
          }
          for (var b = 0; b < 4; b++) {
            _kick(mix, t0 + b * beat, .44);
          }
          _snap(mix, t0 + beat, .09, rng);
          _snap(mix, t0 + 3 * beat, .09, rng);
      }
    }

    if (track.melody) {
      for (final (bar, b, d, m) in _melody) {
        note(mix, bar * barLen + b * beat, d * beat * .95, hz(m), .11, lead,
            attack: .03, release: .35);
      }
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

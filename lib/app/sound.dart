import 'package:audioplayers/audioplayers.dart';

/// The few sound cues the game actually needs.
enum SoundEffect { place, clear, combo, gameOver, tap, coin }

/// Thin wrapper around `audioplayers`. Plays short clips from
/// `assets/sfx/<name>.mp3`.
///
/// No audio files ship with this scaffold yet — [play] swallows the "asset
/// not found" error so the game runs silently rather than crashing until
/// you drop real clips into `assets/sfx/` and list them under `flutter:
/// assets:` in `pubspec.yaml`. (Arrow Bloom instead synthesizes its SFX as
/// raw WAV bytes at startup, which is a nice trick if you'd rather not ship
/// audio files at all — see that project's `app/sound.dart` for the
/// approach — but it's involved enough that it's left out of this first
/// pass rather than ported unverified.)
class Sound {
  Sound._();
  static final instance = Sound._();

  bool enabled = true;

  /// One player per effect, reused so rapid combo hits don't pile up
  /// MediaPlayer instances.
  final Map<SoundEffect, AudioPlayer> _players = {};

  Future<void> init() async {
    for (final fx in SoundEffect.values) {
      _players[fx] = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    }
  }

  static const _files = {
    SoundEffect.place: 'place.mp3',
    SoundEffect.clear: 'clear.mp3',
    SoundEffect.combo: 'combo.mp3',
    SoundEffect.gameOver: 'game_over.mp3',
    SoundEffect.tap: 'tap.mp3',
    SoundEffect.coin: 'coin.mp3',
  };

  Future<void> play(SoundEffect fx) async {
    if (!enabled) return;
    final player = _players[fx];
    final file = _files[fx];
    if (player == null || file == null) return;
    try {
      await player.stop();
      await player.play(AssetSource('sfx/$file'));
    } catch (_) {
      // No clip at assets/sfx/$file yet (or the platform has no audio
      // output, as in some CI/test environments) — play silently.
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
  }
}

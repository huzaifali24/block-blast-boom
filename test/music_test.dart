import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:block_bloom/app/music.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Uint8List wav;
  late Int16List pcm;

  setUpAll(() {
    wav = MusicSynth.render();
    pcm = Int16List.sublistView(wav, 44);
    // Optional: MUSIC_OUT=path flutter test test/music_test.dart writes the
    // loop out so it can be listened to on a computer.
    final out = Platform.environment['MUSIC_OUT'];
    if (out != null) File(out).writeAsBytesSync(wav);
  });

  test('is a valid 32 kHz mono 16-bit WAV of the expected length', () {
    final h = ByteData.sublistView(wav, 0, 44);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(h.getUint16(20, Endian.little), 1); // PCM
    expect(h.getUint16(22, Endian.little), 1); // mono
    expect(h.getUint32(24, Endian.little), 32000);
    expect(h.getUint16(34, Endian.little), 16);
    expect(h.getUint32(40, Endian.little), pcm.length * 2);
    // 16 bars at 100 BPM = 38.4 s.
    expect(pcm.length / MusicSynth.rate, closeTo(38.4, .01));
  });

  test('is audible but never clips', () {
    var peak = 0, sumSq = 0.0, clipped = 0;
    for (final s in pcm) {
      peak = math.max(peak, s.abs());
      sumSq += s * s;
      if (s.abs() >= 32760) clipped++;
    }
    final rms = math.sqrt(sumSq / pcm.length) / 32768;
    expect(clipped, 0);
    expect(peak / 32768, closeTo(.85, .01)); // normalized headroom
    expect(rms, greaterThan(.05), reason: 'track is too quiet');
    expect(rms, lessThan(.4), reason: 'track is too dense/loud');
  });

  test('has no silent gaps anywhere in the loop', () {
    // Every half-second window should contain sound.
    const win = MusicSynth.rate ~/ 2;
    for (var start = 0; start + win <= pcm.length; start += win) {
      var sumSq = 0.0;
      for (var i = start; i < start + win; i++) {
        sumSq += pcm[i] * pcm[i];
      }
      final rms = math.sqrt(sumSq / win) / 32768;
      expect(rms, greaterThan(.01),
          reason: 'near-silence at ${start / MusicSynth.rate}s');
    }
  });

  test('loops seamlessly (no click where the end joins the start)', () {
    // The jump from the last sample to the first should be no bigger than
    // ordinary sample-to-sample movement inside the track.
    var maxStep = 0;
    for (var i = 1; i < pcm.length; i++) {
      maxStep = math.max(maxStep, (pcm[i] - pcm[i - 1]).abs());
    }
    final seam = (pcm.first - pcm.last).abs();
    expect(seam, lessThanOrEqualTo(maxStep));
    expect(seam / 32768, lessThan(.1));
  });

  test('renders identically every time (cache-safe)', () {
    expect(MusicSynth.render(), equals(wav));
  });

  test('menu and tense arrangements are valid, seamless and distinct', () {
    final game = Int16List.sublistView(wav, 44);
    for (final t in [MusicTrack.menu, MusicTrack.tense]) {
      final w = MusicSynth.render(t);
      final p = Int16List.sublistView(w, 44);
      expect(p.length, MusicSynth.lengthOf(t), reason: t.name);
      var peak = 0, sumSq = 0.0, maxStep = 0;
      for (var i = 0; i < p.length; i++) {
        peak = math.max(peak, p[i].abs());
        sumSq += p[i] * p[i];
        if (i > 0) maxStep = math.max(maxStep, (p[i] - p[i - 1]).abs());
      }
      expect(peak / 32768, closeTo(.85, .01), reason: t.name);
      expect(math.sqrt(sumSq / p.length) / 32768, greaterThan(.05), reason: t.name);
      expect((p.first - p.last).abs(), lessThanOrEqualTo(maxStep), reason: t.name);
      expect(p.length == game.length && _same(p, game), isFalse,
          reason: '${t.name} should differ from the game track');
    }
    // Tempo: the tense loop is shorter (faster), the menu loop longer.
    expect(MusicSynth.lengthOf(MusicTrack.tense), lessThan(MusicSynth.length));
    expect(MusicSynth.lengthOf(MusicTrack.menu), greaterThan(MusicSynth.length));
  });
}

bool _same(Int16List a, Int16List b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

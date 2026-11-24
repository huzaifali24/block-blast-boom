import 'dart:typed_data';

import 'package:block_bloom/app/app_state.dart';
import 'package:block_bloom/app/haptics.dart';
import 'package:block_bloom/app/sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zero crossings per sample: a simple stand-in for pitch.
double pitchOf(Uint8List wav) {
  final pcm = Int16List.sublistView(wav, 44);
  // Only the first 0.15 s (the tonal part, before the noise tail fades).
  final n = (22050 * .15).round().clamp(0, pcm.length);
  var crossings = 0;
  for (var i = 1; i < n; i++) {
    if ((pcm[i - 1] < 0) != (pcm[i] < 0)) crossings++;
  }
  return crossings / n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each combo step makes the clear sound higher', () {
    var last = 0.0;
    for (var v = 0; v < Sound.variantsOf(SoundEffect.clear); v++) {
      final p = pitchOf(Sound.renderClip(SoundEffect.clear, v));
      expect(p, greaterThan(last), reason: 'combo step $v');
      last = p;
    }
  });

  test('bigger multi-line clears play a longer flourish', () {
    var last = 0;
    for (var v = 0; v < Sound.variantsOf(SoundEffect.combo); v++) {
      final len = Sound.renderClip(SoundEffect.combo, v).length;
      expect(len, greaterThan(last), reason: 'lines ${v + 2}');
      last = len;
    }
  });

  test('placement has distinct variants so repeats do not grate', () {
    final clips = [
      for (var v = 0; v < Sound.variantsOf(SoundEffect.place); v++)
        Sound.renderClip(SoundEffect.place, v),
    ];
    expect(clips[0], isNot(equals(clips[1])));
    expect(clips[1], isNot(equals(clips[2])));
  });

  group('haptics', () {
    final calls = <String>[];
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppState.load();
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
        return null;
      });
    });

    test('patterns scale with the size of the moment', () async {
      Haptics.clear(lines: 1, combo: 1);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, hasLength(1));

      calls.clear();
      Haptics.clear(lines: 2, combo: 1);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, hasLength(2));

      calls.clear();
      Haptics.clear(lines: 3, combo: 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(calls, hasLength(3));
      expect(calls.first, 'HapticFeedbackType.heavyImpact');

      calls.clear();
      Haptics.allClear();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(calls, hasLength(4));
    });

    test('nothing vibrates when Vibration is off', () async {
      AppState.instance.setHapticsOn(false);
      Haptics.place();
      Haptics.clear(lines: 4, combo: 6);
      Haptics.allClear();
      Haptics.gameOver();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(calls, isEmpty);
    });
  });
}

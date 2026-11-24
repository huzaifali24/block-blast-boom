import 'package:flutter/services.dart';

import 'app_state.dart';

/// Vibration feedback, scaled to how big the moment is. Every call
/// respects the player's Vibration setting.
class Haptics {
  Haptics._();

  static bool get _on => AppState.instance.hapticsOn;

  static void pick() {
    if (_on) HapticFeedback.selectionClick();
  }

  static void place() {
    if (_on) HapticFeedback.lightImpact();
  }

  /// One tap for a single line; a double pulse for doubles or a streak;
  /// a rolling triple for 3+ lines or a long combo.
  static void clear({required int lines, required int combo}) {
    if (!_on) return;
    if (lines >= 3 || combo >= 4) {
      _pattern(const [0, 70, 70],
          [HapticFeedback.heavyImpact, HapticFeedback.mediumImpact, HapticFeedback.lightImpact]);
    } else if (lines == 2 || combo >= 2) {
      _pattern(const [0, 60], [HapticFeedback.mediumImpact, HapticFeedback.lightImpact]);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  static void allClear() {
    if (!_on) return;
    _pattern(const [0, 90, 90, 90], [
      HapticFeedback.heavyImpact,
      HapticFeedback.heavyImpact,
      HapticFeedback.mediumImpact,
      HapticFeedback.lightImpact,
    ]);
  }

  static void gameOver() {
    if (!_on) return;
    _pattern(const [0, 140], [HapticFeedback.heavyImpact, HapticFeedback.mediumImpact]);
  }

  /// Fires [hits] with the given gaps (ms) before each.
  static Future<void> _pattern(List<int> gaps, List<Future<void> Function()> hits) async {
    for (var i = 0; i < hits.length; i++) {
      if (gaps[i] > 0) await Future<void>.delayed(Duration(milliseconds: gaps[i]));
      await hits[i]();
    }
  }
}

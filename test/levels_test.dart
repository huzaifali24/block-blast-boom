import 'package:block_bloom/app/app_state.dart';
import 'package:block_bloom/game/engine.dart';
import 'package:block_bloom/game/levels.dart';
import 'package:block_bloom/game/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('all levels build, are fair, and never start with a full line', () {
    for (var n = 1; n <= Levels.count; n++) {
      final l = Levels.get(n);
      final s = GameSession.adventure(l);
      final lines = s.board.fullLines();
      expect(lines.rows, isEmpty, reason: 'level $n');
      expect(lines.cols, isEmpty, reason: 'level $n');
      expect(l.prefilled.keys.toSet().containsAll(l.gems), isTrue);
      expect(s.tray.any((p) => p != null && s.board.canPlaceAnywhere(p)), isTrue,
          reason: 'level $n starts stuck');
      expect(l.target, greaterThan(0));
      if (l.goal == LevelGoal.gems) expect(l.gems, isNotEmpty);
    }
  });

  test('levels are identical for every player and get harder', () {
    expect(Levels.get(7).prefilled, Levels.get(7).prefilled);
    expect(Levels.get(30).prefilled.length,
        greaterThan(Levels.get(1).prefilled.length));
    expect(Levels.get(28).target, greaterThan(Levels.get(1).target)); // score
  });

  test('stars follow par', () {
    final l = Levels.get(1);
    expect(l.starsFor(l.par), 3);
    expect(l.starsFor(l.par + 1), 2);
    expect(l.starsFor(l.par * 3), 1);
  });

  test('clearing a line collects its gems, and undo puts them back', () {
    final l = Levels.get(3); // gems level
    expect(l.goal, LevelGoal.gems);
    final s = GameSession.adventure(l);
    final gem = l.gems.first;
    final y = gem ~/ 8;
    // Fill the gem's row except one cell, then drop a dot there.
    var hole = -1;
    for (var x = 0; x < 8; x++) {
      final i = y * 8 + x;
      if (s.board.cells[i] == -1) {
        if (hole == -1) {
          hole = x;
        } else {
          s.board.cells[i] = 0;
        }
      }
    }
    if (hole == -1) {
      hole = (gem % 8 + 1) % 8;
      s.board.cells[y * 8 + hole] = -1;
      s.gems.remove(y * 8 + hole);
    }
    s.tray[0] = PieceShape('dot', const [Cell(0, 0)], PieceColor.mint);
    final snap = s.snapshot();
    final before = s.gems.length;
    final r = s.place(0, hole, y);
    expect(r!.clearedRows, contains(y));
    expect(s.gemsCollected, greaterThanOrEqualTo(1));
    expect(s.gems.length, lessThan(before));

    s.restore(snap);
    expect(s.gemsCollected, 0);
    expect(s.gems.length, before);
  });

  test('levelComplete flips when the goal is reached', () {
    final l = Levels.get(1);
    final s = GameSession.adventure(l);
    expect(s.levelComplete, isFalse);
    s.score = l.target;
    expect(l.goal, LevelGoal.score);
    expect(s.levelComplete, isTrue);
  });

  test('completing levels unlocks the next and pays only for improvements', () async {
    SharedPreferences.setMockInitialValues({'coins': 0});
    await AppState.load();
    final app = AppState.instance;
    final l1 = Levels.get(1);
    expect(app.unlockedLevel, 1);

    final first = app.completeLevel(l1, 1);
    expect(first, l1.firstClearCoins + Level.coinsPerStar);
    expect(app.unlockedLevel, 2);

    expect(app.completeLevel(l1, 1), 0); // replay, no improvement
    expect(app.completeLevel(l1, 3), 2 * Level.coinsPerStar);
    expect(app.totalStars, 3);
    expect(app.coins, first + 2 * Level.coinsPerStar);
  });
}

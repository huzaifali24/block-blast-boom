import 'dart:math';

import '../l10n/l10n.dart';
import 'engine.dart';

/// What a level asks of the player.
enum LevelGoal {
  score('Score', 'Reach {n} points'),
  lines('Lines', 'Clear {n} lines'),
  gems('Gems', 'Collect {n} gems');

  const LevelGoal(this.label, this._text);
  final String label;
  final String _text;
  String describe(int n) => tr(_text, {'n': n});
}

/// One Adventure level: a goal, a starting board (some blocks already
/// placed, a few holding gems) and a par move count for stars.
class Level {
  const Level({
    required this.number,
    required this.goal,
    required this.target,
    required this.par,
    required this.seed,
    required this.prefilled,
    required this.gems,
  });

  /// 1-based.
  final int number;
  final LevelGoal goal;
  final int target;

  /// Moves for 3 stars; up to 1.5x par earns 2 stars; anything else 1.
  final int par;
  final int seed;

  /// Board index -> color index of blocks already on the board.
  final Map<int, int> prefilled;

  /// Board indices (all inside [prefilled]) whose blocks hold a gem.
  final Set<int> gems;

  int starsFor(int moves) => moves <= par
      ? 3
      : moves <= (par * 1.5).ceil()
          ? 2
          : 1;

  /// Coins for finishing it the first time.
  int get firstClearCoins => 20 + number * 4;

  /// Extra coins for each newly earned star.
  static const coinsPerStar = 10;
}

/// The Adventure campaign. Levels are generated deterministically from
/// their number, so every player gets the same 30 boards, and difficulty
/// ramps smoothly: more starting blocks, bigger targets, tighter par.
class Levels {
  Levels._();

  static const count = 30;
  static const boardSize = 8;

  static final _cache = <int, Level>{};

  static Level get(int number) {
    assert(number >= 1 && number <= count);
    return _cache[number] ??= _build(number);
  }

  static Level _build(int n) {
    final rng = Random(9000 + n * 37);
    // Goals rotate so consecutive levels feel different.
    final goal = LevelGoal.values[(n - 1) % 3];
    final t = (n - 1) / (count - 1); // 0..1 difficulty

    // Starting clutter: 4 -> ~22 blocks.
    final blocks = 4 + (t * 18).round() + rng.nextInt(3);
    final gemCount = goal == LevelGoal.gems ? 3 + (t * 5).round() : 0;

    final prefilled = <int, int>{};
    final board = Board(boardSize);
    var guard = 0;
    while (prefilled.length < blocks && guard++ < 2000) {
      // Bias clutter toward the lower half, like a game already under way.
      final y = boardSize - 1 - (rng.nextDouble() * rng.nextDouble() * boardSize).floor();
      final x = rng.nextInt(boardSize);
      final i = board.indexOf(x, y);
      if (prefilled.containsKey(i)) continue;
      final color = rng.nextInt(7);
      board.cells[i] = color;
      // Never start with a completed line (it would clear instantly).
      final lines = board.fullLines();
      if (lines.rows.isNotEmpty || lines.cols.isNotEmpty) {
        board.cells[i] = -1;
        continue;
      }
      prefilled[i] = color;
    }

    final gems = <int>{};
    final keys = prefilled.keys.toList()..shuffle(rng);
    for (final i in keys.take(gemCount)) {
      gems.add(i);
    }

    final int target;
    final int par;
    switch (goal) {
      case LevelGoal.score:
        target = (150 + t * 1350).round() ~/ 10 * 10; // 150 -> 1500
        par = 8 + (t * 22).round();
      case LevelGoal.lines:
        target = 3 + (t * 17).round(); // 3 -> 20
        par = target * 2 + 2;
      case LevelGoal.gems:
        target = gems.length;
        par = 6 + gems.length * 2;
    }

    return Level(
      number: n,
      goal: goal,
      target: target,
      par: par,
      seed: 4242 + n,
      prefilled: Map.unmodifiable(prefilled),
      gems: Set.unmodifiable(gems),
    );
  }
}

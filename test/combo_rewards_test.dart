import 'package:block_bloom/game/engine.dart';
import 'package:flutter_test/flutter_test.dart';

PlacementResult r({int lines = 1, int combo = 1, bool allClear = false}) =>
    PlacementResult(
      placedCells: 3,
      clearedRows: List.generate(lines, (i) => i),
      clearedCols: const [],
      clearedCells: const {},
      clearedCellColors: const {},
      points: 0,
      comboAfter: combo,
      allClear: allClear,
    );

void main() {
  test('ordinary moves pay nothing', () {
    expect(ComboRewards.coinsFor(r(lines: 0, combo: 0)), 0);
    expect(ComboRewards.coinsFor(r(lines: 1, combo: 1)), 0);
    expect(ComboRewards.coinsFor(r(lines: 2, combo: 2)), 0);
  });

  test('combos pay from 3 in a row, growing, capped', () {
    expect(ComboRewards.coinsFor(r(combo: 3)), 5);
    expect(ComboRewards.coinsFor(r(combo: 4)), 10);
    expect(ComboRewards.coinsFor(r(combo: 7)), 25);
    expect(ComboRewards.coinsFor(r(combo: 20)), 25);
  });

  test('big multi-line clears and all-clears add up', () {
    expect(ComboRewards.coinsFor(r(lines: 3)), 5);
    expect(ComboRewards.coinsFor(r(lines: 4)), 10);
    expect(ComboRewards.coinsFor(r(lines: 2, allClear: true)), 50);
    expect(ComboRewards.coinsFor(r(lines: 4, combo: 3, allClear: true)), 5 + 10 + 50);
  });

  test('celebrations are for all-clears and 5+ combos', () {
    expect(ComboRewards.celebrate(r(combo: 4)), isFalse);
    expect(ComboRewards.celebrate(r(combo: 5)), isTrue);
    expect(ComboRewards.celebrate(r(allClear: true)), isTrue);
  });
}

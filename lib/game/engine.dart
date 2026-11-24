import 'dart:math';

import 'shapes.dart';

export 'shapes.dart' show Cell, PieceShape, PieceColor, PieceBag, Shapes;

/// The square grid blocks are placed on. `-1` means empty; any other value
/// is the [PieceColor.index] of whatever piece filled that cell, kept around
/// so a cleared cell can still flash the right color on its way out.
class Board {
  Board(this.size) : cells = List<int>.filled(size * size, -1);

  Board._raw(this.size, this.cells);

  final int size;
  final List<int> cells;

  int indexOf(int x, int y) => y * size + x;
  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;
  bool isEmptyAt(int x, int y) => inBounds(x, y) && cells[indexOf(x, y)] == -1;
  int colorAt(int x, int y) => cells[indexOf(x, y)];

  /// Share of cells currently filled, 0..1. Used for a "board getting full"
  /// warning in the UI.
  double get fillRatio =>
      cells.where((c) => c != -1).length / (size * size);

  /// Whether [shape] fits with its bounding-box origin at ([ox],[oy]).
  bool canPlace(PieceShape shape, int ox, int oy) {
    for (final c in shape.cells) {
      if (!isEmptyAt(ox + c.x, oy + c.y)) return false;
    }
    return true;
  }

  /// Whether [shape] fits anywhere on the board at all. Boards here are
  /// small (8x8/9x9), so a brute-force scan is cheap enough to call on
  /// every tray change and after every placement.
  bool canPlaceAnywhere(PieceShape shape) {
    for (var oy = 0; oy <= size - shape.height; oy++) {
      for (var ox = 0; ox <= size - shape.width; ox++) {
        if (canPlace(shape, ox, oy)) return true;
      }
    }
    return false;
  }

  /// Every legal top-left origin for [shape]. Small enough boards that the
  /// UI can use this directly for a "best spot" hint.
  List<Cell> validOrigins(PieceShape shape) => [
        for (var oy = 0; oy <= size - shape.height; oy++)
          for (var ox = 0; ox <= size - shape.width; ox++)
            if (canPlace(shape, ox, oy)) Cell(ox, oy),
      ];

  /// Marks [shape]'s cells as filled with [colorIndex]. Caller must have
  /// already checked [canPlace]; this does not validate.
  void place(PieceShape shape, int ox, int oy, int colorIndex) {
    for (final c in shape.cells) {
      cells[indexOf(ox + c.x, oy + c.y)] = colorIndex;
    }
  }

  /// Rows and columns that are completely filled right now.
  ({List<int> rows, List<int> cols}) fullLines() {
    final rows = <int>[];
    for (var y = 0; y < size; y++) {
      var full = true;
      for (var x = 0; x < size; x++) {
        if (isEmptyAt(x, y)) {
          full = false;
          break;
        }
      }
      if (full) rows.add(y);
    }
    final cols = <int>[];
    for (var x = 0; x < size; x++) {
      var full = true;
      for (var y = 0; y < size; y++) {
        if (isEmptyAt(x, y)) {
          full = false;
          break;
        }
      }
      if (full) cols.add(x);
    }
    return (rows: rows, cols: cols);
  }

  /// Empties every cell in [rows] and [cols], returning the board indices
  /// that were actually cleared (a cell at a cleared row/col intersection
  /// is only counted once), paired with the color each held *before* it was
  /// emptied — the UI needs that to play a clear effect in the right color,
  /// since by the time this returns the board itself is already empty there.
  ({Set<int> cells, Map<int, int> colors}) clearLines(
      List<int> rows, List<int> cols) {
    final cleared = <int>{};
    for (final y in rows) {
      for (var x = 0; x < size; x++) {
        cleared.add(indexOf(x, y));
      }
    }
    for (final x in cols) {
      for (var y = 0; y < size; y++) {
        cleared.add(indexOf(x, y));
      }
    }
    final colors = {for (final i in cleared) i: cells[i]};
    for (final i in cleared) {
      cells[i] = -1;
    }
    return (cells: cleared, colors: colors);
  }

  /// Whether every piece in [tray] is stuck (ignoring `null` slots already
  /// used up this tray): the standard end-of-game condition.
  bool get isEmpty => cells.every((c) => c == -1);

  bool isGameOver(Iterable<PieceShape?> tray) =>
      tray.every((s) => s == null || !canPlaceAnywhere(s));

  Board clone() => Board._raw(size, List<int>.from(cells));
}

/// Tunable point values. Kept as named constants (not magic numbers in
/// [Scoring.scoreMove]) so balancing the game later is a one-line change.
class ScoreRules {
  static const perCellPlaced = 1;
  static const perLineBase = 10;
  static const perComboStep = 10;

  /// Bonus for a move that leaves the whole board empty.
  static const allClearBonus = 300;
}

/// Result of one placement: how many points it earned and the combo streak
/// it leaves behind for the next move.
typedef ScoreResult = ({int points, int comboAfter});

/// Pure scoring math, separated from [Board] so it can be unit-tested
/// without any grid at all.
class Scoring {
  Scoring._();

  /// Points for placing a piece that covered [placedCells] cells and
  /// cleared [linesCleared] rows+columns simultaneously, given the combo
  /// streak ([comboBefore]) going into this move.
  ///
  /// Clearing nothing resets the combo to 0. Clearing lines pays a
  /// per-line amount that grows with the *square* of how many lines went
  /// at once (so a double clear is worth much more than two singles), plus
  /// a flat bonus per combo step so back-to-back clearing turns compound.
  static ScoreResult scoreMove({
    required int placedCells,
    required int linesCleared,
    required int comboBefore,
  }) {
    var points = placedCells * ScoreRules.perCellPlaced;
    if (linesCleared <= 0) {
      return (points: points, comboAfter: 0);
    }
    final comboAfter = comboBefore + 1;
    final linePoints =
        ScoreRules.perLineBase * linesCleared * linesCleared;
    final comboBonus = ScoreRules.perComboStep * (comboAfter - 1);
    points += linePoints + comboBonus;
    return (points: points, comboAfter: comboAfter);
  }
}

/// Everything that happened when a piece was placed: used by the UI to
/// drive score ticks and clear animations, and by [session.dart] to update
/// the running score/combo.
class PlacementResult {
  const PlacementResult({
    required this.placedCells,
    required this.clearedRows,
    required this.clearedCols,
    required this.clearedCells,
    required this.clearedCellColors,
    required this.points,
    required this.comboAfter,
    this.allClear = false,
  });

  final int placedCells;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final Set<int> clearedCells;

  /// `clearedCells` index -> the [PieceColor.index] it held just before
  /// being cleared (the board itself is already empty there by the time
  /// this result reaches its caller).
  final Map<int, int> clearedCellColors;
  final int points;
  final int comboAfter;

  /// The move cleared lines and left the board completely empty
  /// ([ScoreRules.allClearBonus] is already included in [points]).
  final bool allClear;

  int get linesCleared => clearedRows.length + clearedCols.length;
  bool get cleared => linesCleared > 0;
}

/// Orchestrates one full turn: place [shape] at ([ox],[oy]) on [board],
/// clear any lines that completes, and score it. Mutates [board]. The
/// caller is expected to have already checked [Board.canPlace].
PlacementResult applyPlacement({
  required Board board,
  required PieceShape shape,
  required int ox,
  required int oy,
  required int colorIndex,
  required int comboBefore,
}) {
  board.place(shape, ox, oy, colorIndex);
  final lines = board.fullLines();
  final hasClear = lines.rows.isNotEmpty || lines.cols.isNotEmpty;
  final cleared = hasClear
      ? board.clearLines(lines.rows, lines.cols)
      : (cells: const <int>{}, colors: const <int, int>{});
  final scored = Scoring.scoreMove(
    placedCells: shape.cellCount,
    linesCleared: lines.rows.length + lines.cols.length,
    comboBefore: comboBefore,
  );
  final allClear = hasClear && board.isEmpty;
  return PlacementResult(
    placedCells: shape.cellCount,
    clearedRows: lines.rows,
    clearedCols: lines.cols,
    clearedCells: cleared.cells,
    clearedCellColors: cleared.colors,
    points: scored.points + (allClear ? ScoreRules.allClearBonus : 0),
    comboAfter: scored.comboAfter,
    allClear: allClear,
  );
}

/// Coins paid out *during* a game for skilful moves, on top of the
/// end-of-game coins: long combos, big multi-line clears, all-clears.
class ComboRewards {
  ComboRewards._();

  static const comboStart = 3;
  static const perComboStep = 5;
  static const comboCap = 7;
  static const perBigLine = 5;
  static const allClear = 50;

  /// Coins for the move described by [r] (0 for ordinary moves).
  static int coinsFor(PlacementResult r) {
    if (!r.cleared) return 0;
    var coins = 0;
    if (r.comboAfter >= comboStart) {
      coins += perComboStep * (min(r.comboAfter, comboCap) - comboStart + 1);
    }
    if (r.linesCleared >= 3) coins += perBigLine * (r.linesCleared - 2);
    if (r.allClear) coins += allClear;
    return coins;
  }

  /// Moves worth a full-screen celebration.
  static bool celebrate(PlacementResult r) => r.allClear || r.comboAfter >= 5;
}

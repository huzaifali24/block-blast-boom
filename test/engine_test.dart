import 'dart:math';

import 'package:block_boom/game/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('place marks occupied cells and canPlace respects bounds', () {
    final board = Board(4);
    final shape = PieceShape('test', const [Cell(0, 0), Cell(1, 0)], PieceColor.amber);

    expect(board.canPlace(shape, 0, 0), isTrue);
    expect(board.canPlace(shape, 3, 0), isFalse); // (1,0) cell would land at x=4, out of bounds

    board.place(shape, 0, 0, PieceColor.amber.index);
    expect(board.colorAt(0, 0), PieceColor.amber.index);
    expect(board.colorAt(1, 0), PieceColor.amber.index);
    expect(board.canPlace(shape, 0, 0), isFalse); // now occupied
  });

  test('fullLines detects completed rows/cols and clearLines snapshots pre-clear colors', () {
    final board = Board(3);
    board.place(PieceShape('a', const [Cell(0, 0)], PieceColor.amber), 0, 0,
        PieceColor.amber.index);
    board.place(PieceShape('b', const [Cell(0, 0)], PieceColor.pink), 1, 0,
        PieceColor.pink.index);
    board.place(PieceShape('c', const [Cell(0, 0)], PieceColor.cyan), 2, 0,
        PieceColor.cyan.index);

    final lines = board.fullLines();
    expect(lines.rows, [0]);
    expect(lines.cols, isEmpty);

    final result = board.clearLines(lines.rows, lines.cols);
    expect(result.cells, {0, 1, 2});
    expect(result.colors[0], PieceColor.amber.index);
    expect(result.colors[1], PieceColor.pink.index);
    expect(result.colors[2], PieceColor.cyan.index);
    expect(board.colorAt(0, 0), -1); // cleared afterwards
  });

  test('scoreMove rewards multi-clears and combo streaks, and resets on a miss', () {
    final single = Scoring.scoreMove(placedCells: 4, linesCleared: 1, comboBefore: 0);
    expect(single.points, 14); // 4 placed + 10*1^2 line bonus + 0 combo bonus
    expect(single.comboAfter, 1);

    final noClear = Scoring.scoreMove(placedCells: 3, linesCleared: 0, comboBefore: 2);
    expect(noClear.points, 3);
    expect(noClear.comboAfter, 0); // a non-clearing move resets the streak

    final doubleClear = Scoring.scoreMove(placedCells: 5, linesCleared: 2, comboBefore: 1);
    expect(doubleClear.points, 55); // 5 + 10*2^2 + 10*(2-1)
    expect(doubleClear.comboAfter, 2);
  });

  test('applyPlacement clears exactly the completed row and column together', () {
    final board = Board(3);
    final filler = PieceShape('f', const [Cell(0, 0)], PieceColor.amber);
    // Fill everything row 2 and column 2 need except their shared corner.
    board.place(filler, 0, 2, PieceColor.amber.index);
    board.place(filler, 1, 2, PieceColor.amber.index);
    board.place(filler, 2, 0, PieceColor.amber.index);
    board.place(filler, 2, 1, PieceColor.amber.index);

    final dot = PieceShape('dot', const [Cell(0, 0)], PieceColor.mint);
    final result = applyPlacement(
      board: board,
      shape: dot,
      ox: 2,
      oy: 2,
      colorIndex: PieceColor.mint.index,
      comboBefore: 0,
    );

    expect(result.linesCleared, 2);
    expect(result.clearedRows, [2]);
    expect(result.clearedCols, [2]);
    expect(result.clearedCells.length, 5); // 3 + 3 cells - 1 shared corner
    expect(result.clearedCellColors[board.indexOf(2, 2)], PieceColor.mint.index);
    expect(result.clearedCellColors[board.indexOf(0, 2)], PieceColor.amber.index);
    expect(board.colorAt(0, 0), -1); // was never touched
    expect(board.colorAt(2, 0), -1); // was filled, now cleared
    expect(result.comboAfter, 1);
  });

  test('PieceShape rotation re-normalizes to a non-negative box and swaps width/height', () {
    final shape = PieceShape('tromino_i', const [Cell(0, 0), Cell(1, 0), Cell(2, 0)],
        PieceColor.amber);
    expect(shape.width, 3);
    expect(shape.height, 1);

    final rotated = shape.rotated();
    expect(rotated.cells.every((c) => c.x >= 0 && c.y >= 0), isTrue);
    expect(rotated.width, 1);
    expect(rotated.height, 3);
  });

  test('Shapes.all collapses symmetric rotations and keeps each family\'s total weight', () {
    final byFamily = <String, List<double>>{};
    for (final (shape, weight) in Shapes.all) {
      byFamily.putIfAbsent(shape.family, () => []).add(weight);
    }

    // A perfect square looks the same after every 90° turn: one orientation.
    expect(byFamily['tetromino_o'], hasLength(1));
    expect(byFamily['tetromino_o']!.first, closeTo(4.0, 1e-9));

    // The L-tetromino has no rotational symmetry: all four turns are distinct.
    expect(byFamily['tetromino_l'], hasLength(4));
    expect(byFamily['tetromino_l']!.reduce((a, b) => a + b), closeTo(4.0, 1e-9));

    // The S/Z tetrominoes repeat after 180°: exactly two distinct turns.
    expect(byFamily['tetromino_s'], hasLength(2));
    expect(byFamily['tetromino_z'], hasLength(2));
  });

  test('a clear that empties the whole board earns the all-clear bonus', () {
    final board = Board(3);
    final filler = PieceShape('f', const [Cell(0, 0)], PieceColor.amber);
    board.place(filler, 0, 0, 0);
    board.place(filler, 1, 0, 0);
    final dot = PieceShape('dot', const [Cell(0, 0)], PieceColor.mint);
    final result = applyPlacement(
        board: board, shape: dot, ox: 2, oy: 0, colorIndex: 3, comboBefore: 0);
    expect(result.allClear, isTrue);
    expect(result.points, 1 + 10 + ScoreRules.allClearBonus);

    // Clearing a line while other blocks remain is not an all-clear.
    final board2 = Board(3);
    board2.place(filler, 0, 0, 0);
    board2.place(filler, 1, 0, 0);
    board2.place(filler, 0, 2, 0);
    final r2 = applyPlacement(
        board: board2, shape: dot, ox: 2, oy: 0, colorIndex: 3, comboBefore: 0);
    expect(r2.allClear, isFalse);
    expect(r2.points, 11);
  });

  test('each dealt tray paints its three pieces in three different colors', () {
    final bag = PieceBag(Random(42));
    for (var i = 0; i < 50; i++) {
      final tray = bag.nextTray();
      expect(tray.map((s) => s.color).toSet(), hasLength(3));
    }
  });
}

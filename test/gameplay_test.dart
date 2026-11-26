import 'package:block_boom/game/engine.dart';
import 'package:block_boom/game/modes.dart';
import 'package:block_boom/game/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a fresh classic session deals a full tray of three pieces', () {
    final s = GameSession.classic();
    expect(s.tray, hasLength(3));
    expect(s.tray.every((p) => p != null), isTrue);
    expect(s.score, 0);
    expect(s.gameOver, isFalse);
  });

  test('placing a piece empties its slot, scores it, and tracks moves played', () {
    final s = GameSession.classic();
    var i = -1;
    for (var k = 0; k < 3; k++) {
      if (s.canPlace(k, 0, 0)) {
        i = k;
        break;
      }
    }
    expect(i, greaterThanOrEqualTo(0),
        reason: 'every fresh tray should fit something at (0,0) on an empty board');

    final result = s.place(i, 0, 0);
    expect(result, isNotNull);
    expect(s.tray[i], isNull);
    expect(s.score, result!.points);
    expect(s.movesPlayed, 1);
  });

  test('placing somewhere illegal leaves the session untouched', () {
    final s = GameSession.classic();
    // Every tray piece is normalized to start at (0,0), so a huge negative
    // origin can never be a legal placement for anything.
    final result = s.place(0, -50, -50);
    expect(result, isNull);
    expect(s.score, 0);
    expect(s.movesPlayed, 0);
  });

  test('daily boards are deterministic for the same calendar day', () {
    final day = DateTime(2026, 3, 14);
    final seed = DailyChallenge.seedFor(day);

    final a = GameSession.seeded(seed, boardSize: DailyChallenge.boardSize);
    final b = GameSession.seeded(seed, boardSize: DailyChallenge.boardSize);
    expect(a.tray.map((p) => p?.family).toList(), b.tray.map((p) => p?.family).toList());

    expect(DailyChallenge.seedFor(day), DailyChallenge.seedFor(DateTime(2026, 3, 14)));
    expect(DailyChallenge.sameDay(day, DateTime(2026, 3, 14, 23, 59)), isTrue);
    expect(DailyChallenge.sameDay(day, DateTime(2026, 3, 15)), isFalse);
  });

  test('a board is only "game over" once nothing left fits anywhere', () {
    final board = Board(2); // tiny board, cheap to fill by hand
    final filler = PieceShape('f', const [Cell(0, 0)], PieceColor.amber);
    board.place(filler, 0, 0, PieceColor.amber.index);
    board.place(filler, 1, 0, PieceColor.amber.index);
    board.place(filler, 0, 1, PieceColor.amber.index);
    // Only (1,1) is still empty.

    final domino = PieceShape('domino', const [Cell(0, 0), Cell(1, 0)], PieceColor.pink);
    expect(board.isGameOver([domino]), isTrue);

    final dot = PieceShape('dot', const [Cell(0, 0)], PieceColor.mint);
    expect(board.isGameOver([dot]), isFalse);

    // A slot already spent this tray (null) never blocks the others.
    expect(board.isGameOver([null, domino]), isTrue);
    expect(board.isGameOver([null, dot]), isFalse);
  });

  test('a fresh tray always has at least one piece that fits when room exists', () {
    // Leave only scattered single holes: the bag must keep re-dealing until
    // something fits (a lone dot or a domino), rather than ending the game.
    for (var seed = 0; seed < 40; seed++) {
      final s = GameSession.seeded(seed);
      final b = s.board;
      for (var i = 0; i < b.cells.length; i++) {
        b.cells[i] = 0;
      }
      b.cells[b.indexOf(3, 3)] = -1;
      b.cells[b.indexOf(4, 3)] = -1;
      b.cells[b.indexOf(3, 4)] = -1;
      b.cells[b.indexOf(4, 4)] = -1;
      // Use up the tray so a new one is dealt against this board.
      s.tray = [null, null, null];
      s.refillForTest();
      expect(s.tray.any((p) => p != null && b.canPlaceAnywhere(p)), isTrue,
          reason: 'seed $seed dealt an unplayable tray');
    }
  });
}

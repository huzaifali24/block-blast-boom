import 'package:block_bloom/game/engine.dart';
import 'package:block_bloom/game/session.dart';
import 'package:flutter_test/flutter_test.dart';

GameSession fullBoardSession({int leaveEmpty = 0}) {
  final s = GameSession.seeded(7);
  final b = s.board;
  for (var i = 0; i < b.cells.length; i++) {
    b.cells[i] = i % 7;
  }
  for (var i = 0; i < leaveEmpty; i++) {
    b.cells[i * 9] = -1; // diagonal holes
  }
  return s;
}

void main() {
  test('undo restores board, tray, score and combo exactly', () {
    final s = GameSession.seeded(1);
    final snap = s.snapshot();
    final cellsBefore = List<int>.of(s.board.cells);
    final trayBefore = List<PieceShape?>.of(s.tray);
    final i = s.tray
        .indexWhere((p) => p != null && s.canPlace(s.tray.indexOf(p), 0, 0));
    s.place(i, 0, 0);
    expect(s.movesPlayed, 1);

    s.restore(snap);
    expect(s.board.cells, cellsBefore);
    expect(s.tray, trayBefore);
    expect(s.score, 0);
    expect(s.combo, 0);
    expect(s.movesPlayed, 0);
  });

  test('bomb clears the 3x3 around a cell, clipped at the edges', () {
    final s = fullBoardSession();
    final centre = s.bomb(4, 4);
    expect(centre, hasLength(9));
    for (var y = 3; y <= 5; y++) {
      for (var x = 3; x <= 5; x++) {
        expect(s.board.isEmptyAt(x, y), isTrue);
      }
    }
    expect(s.board.isEmptyAt(2, 4), isFalse);

    final corner = s.bomb(0, 0);
    expect(corner, hasLength(4)); // only the in-bounds quarter
  });

  test('bomb reports the colors it destroyed and can end a game over', () {
    final s = fullBoardSession();
    s.gameOver = true;
    final cleared = s.bomb(1, 1);
    expect(cleared[s.board.indexOf(0, 0)], 0);
    expect(s.gameOver, isFalse, reason: 'a 3x3 hole fits most pieces');
  });

  test('rotate turns a tray piece 90 degrees', () {
    final s = GameSession.seeded(3);
    s.tray[0] = PieceShape(
        'i3', const [Cell(0, 0), Cell(1, 0), Cell(2, 0)], PieceColor.amber);
    expect(s.rotate(0), isTrue);
    expect(s.tray[0]!.width, 1);
    expect(s.tray[0]!.height, 3);
    expect(s.tray[0]!.color, PieceColor.amber);
    s.tray[1] = null;
    expect(s.rotate(1), isFalse);
  });

  test('shuffle deals a full new tray', () {
    final s = GameSession.seeded(5);
    s.tray[0] = null;
    s.tray[1] = null;
    s.shuffle();
    expect(s.tray.every((p) => p != null), isTrue);
  });

  test('revive clears the fullest lines, deals playable pieces, keeps score',
      () {
    final s = fullBoardSession(leaveEmpty: 1);
    s.score = 900;
    s.combo = 3;
    s.gameOver = true;
    final cleared = s.revive();
    // 3 rows + 3 cols on 8x8 = 24 + 24 - 9 overlaps = 39 cells (minus the
    // one already-empty hole if it fell inside).
    expect(cleared.length, inInclusiveRange(38, 39));
    expect(s.gameOver, isFalse);
    expect(s.tray.any((p) => p != null && s.board.canPlaceAnywhere(p)), isTrue);
    expect(s.score, 900);
    expect(s.combo, 3);
  });
}

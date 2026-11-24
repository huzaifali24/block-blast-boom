import 'dart:math';

import 'package:flutter/foundation.dart';

import 'engine.dart';
import 'modes.dart';

/// Mutable play state for one game: the board, the current tray of up to
/// three pieces, score and combo. [engine.dart] stays pure (board + scoring
/// math only); this is the thin layer the UI actually drives.
class GameSession {
  GameSession({
    required this.mode,
    int? seed,
    int boardSize = 8,
  })  : board = Board(boardSize),
        _bag = PieceBag(Random(seed ?? _randomSeed())),
        tray = List<PieceShape?>.filled(3, null, growable: false) {
    _refillIfEmpty();
  }

  /// A seeded game, for [GameMode.daily] or for replaying a specific seed
  /// (e.g. a shared challenge link later).
  factory GameSession.seeded(int seed, {int boardSize = 8}) =>
      GameSession(mode: GameMode.daily, seed: seed, boardSize: boardSize);

  factory GameSession.classic({int boardSize = 8}) =>
      GameSession(mode: GameMode.classic, boardSize: boardSize);

  static int _randomSeed() => DateTime.now().microsecondsSinceEpoch;

  final GameMode mode;
  final Board board;
  final PieceBag _bag;

  /// Always length 3. A `null` slot means that piece has already been
  /// placed this tray; once every slot is `null` a fresh tray is dealt.
  List<PieceShape?> tray;

  int score = 0;
  int combo = 0;
  int movesPlayed = 0;
  int linesClearedTotal = 0;
  bool gameOver = false;

  /// How many fresh trays to try before accepting one where nothing fits.
  static const _dealAttempts = 16;

  /// Deals a new tray once all three slots are used. Re-deals (a bounded
  /// number of times) until at least one piece fits the board, so a game
  /// only ends when the player's own placements box them in, not because
  /// the bag dealt three impossible pieces onto a board with room left.
  void _refillIfEmpty() {
    if (!tray.every((s) => s == null)) return;
    var next = _bag.nextTray();
    for (var i = 1;
        i < _dealAttempts && !next.any(board.canPlaceAnywhere);
        i++) {
      next = _bag.nextTray();
    }
    tray = List<PieceShape?>.of(next, growable: false);
  }

  @visibleForTesting
  void refillForTest() => _refillIfEmpty();

  bool canPlace(int trayIndex, int ox, int oy) {
    final shape = tray[trayIndex];
    return shape != null && board.canPlace(shape, ox, oy);
  }

  /// Every legal top-left origin for the piece in tray slot [trayIndex], for
  /// the UI to show "will it fit" highlighting while dragging.
  List<Cell> validOrigins(int trayIndex) {
    final shape = tray[trayIndex];
    return shape == null ? const [] : board.validOrigins(shape);
  }

  /// Places the piece in tray slot [trayIndex] at ([ox],[oy]). Returns the
  /// result of the turn, or `null` if that placement isn't legal (nothing is
  /// mutated in that case). Updates score/combo, refills the tray once all
  /// three slots are used, and re-evaluates [gameOver].
  PlacementResult? place(int trayIndex, int ox, int oy) {
    if (gameOver) return null;
    final shape = tray[trayIndex];
    if (shape == null || !board.canPlace(shape, ox, oy)) return null;

    final result = applyPlacement(
      board: board,
      shape: shape,
      ox: ox,
      oy: oy,
      colorIndex: shape.color.index,
      comboBefore: combo,
    );

    tray[trayIndex] = null;
    score += result.points;
    combo = result.comboAfter;
    movesPlayed++;
    linesClearedTotal += result.linesCleared;

    _refillIfEmpty();
    gameOver = board.isGameOver(tray);
    return result;
  }

  // ------------------------------------------------------------ power-ups

  /// Captures everything a single Undo needs to restore.
  SessionSnapshot snapshot() => SessionSnapshot._(
        List<int>.of(board.cells),
        List<PieceShape?>.of(tray),
        score,
        combo,
        movesPlayed,
        linesClearedTotal,
      );

  /// Puts the game back exactly as it was at [s] (Undo).
  void restore(SessionSnapshot s) {
    board.cells.setAll(0, s.cells);
    tray = List<PieceShape?>.of(s.tray, growable: false);
    score = s.score;
    combo = s.combo;
    movesPlayed = s.movesPlayed;
    linesClearedTotal = s.linesCleared;
    gameOver = board.isGameOver(tray);
  }

  /// Bomb: empties the 3x3 area centred on ([cx],[cy]). Returns each
  /// cleared cell index and the color it held (for the explosion effect).
  /// Doesn't score — power-ups make room, they don't buy points.
  Map<int, int> bomb(int cx, int cy) {
    final cleared = <int, int>{};
    for (var y = cy - 1; y <= cy + 1; y++) {
      for (var x = cx - 1; x <= cx + 1; x++) {
        if (!board.inBounds(x, y)) continue;
        final i = board.indexOf(x, y);
        if (board.cells[i] != -1) {
          cleared[i] = board.cells[i];
          board.cells[i] = -1;
        }
      }
    }
    gameOver = board.isGameOver(tray);
    return cleared;
  }

  /// Rotate: turns the piece in [trayIndex] 90° clockwise.
  bool rotate(int trayIndex) {
    final s = tray[trayIndex];
    if (s == null) return false;
    tray[trayIndex] = s.rotated();
    gameOver = board.isGameOver(tray);
    return true;
  }

  /// Shuffle: replaces the whole tray with three fresh pieces (at least one
  /// of which fits, when anything can).
  void shuffle() {
    tray = List<PieceShape?>.filled(3, null, growable: false);
    _refillIfEmpty();
    gameOver = board.isGameOver(tray);
  }

  /// Revive: clears the three fullest rows and three fullest columns and
  /// deals a fresh tray, so a finished game can continue. Score and combo
  /// are kept. Returns the cleared cells and their colors.
  Map<int, int> revive() {
    final n = board.size;
    int filledRow(int y) => [
          for (var x = 0; x < n; x++) board.cells[board.indexOf(x, y)]
        ].where((c) => c != -1).length;
    int filledCol(int x) => [
          for (var y = 0; y < n; y++) board.cells[board.indexOf(x, y)]
        ].where((c) => c != -1).length;
    final rows = [for (var y = 0; y < n; y++) y]
      ..sort((a, b) => filledRow(b) - filledRow(a));
    final cols = [for (var x = 0; x < n; x++) x]
      ..sort((a, b) => filledCol(b) - filledCol(a));
    final cleared = <int, int>{};
    void clear(int x, int y) {
      final i = board.indexOf(x, y);
      if (board.cells[i] != -1) cleared[i] = board.cells[i];
      board.cells[i] = -1;
    }

    for (final y in rows.take(3)) {
      for (var x = 0; x < n; x++) {
        clear(x, y);
      }
    }
    for (final x in cols.take(3)) {
      for (var y = 0; y < n; y++) {
        clear(x, y);
      }
    }
    shuffle();
    return cleared;
  }

  /// Whether at least one tray piece fits somewhere right now. The UI calls
  /// this to drive e.g. a "no moves left" warning before [gameOver] is
  /// final (it's the same check [gameOver] already uses internally).
  bool get hasAnyMove => !board.isGameOver(tray);
}

/// A saved game state for [GameSession.restore].
class SessionSnapshot {
  SessionSnapshot._(this.cells, this.tray, this.score, this.combo,
      this.movesPlayed, this.linesCleared);
  final List<int> cells;
  final List<PieceShape?> tray;
  final int score;
  final int combo;
  final int movesPlayed;
  final int linesCleared;
}

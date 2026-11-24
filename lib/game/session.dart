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

  /// Whether at least one tray piece fits somewhere right now. The UI calls
  /// this to drive e.g. a "no moves left" warning before [gameOver] is
  /// final (it's the same check [gameOver] already uses internally).
  bool get hasAnyMove => !board.isGameOver(tray);
}

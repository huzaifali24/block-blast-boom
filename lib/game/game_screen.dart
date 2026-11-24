import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/sound.dart';
import '../app/theme.dart';
import 'board_painter.dart';
import 'engine.dart';
import 'modes.dart';
import 'session.dart';
import 'skins.dart';

/// The playable screen: board, tray, score HUD, and the game-over sheet.
/// Works for both [GameMode.classic] and [GameMode.daily] — only how the
/// [GameSession] is seeded differs.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode, this.day});

  final GameMode mode;

  /// Which calendar day's board to play. Required for [GameMode.daily];
  /// ignored otherwise. Defaults to today.
  final DateTime? day;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late DateTime _day = widget.day ?? DateTime.now();
  late GameSession _session = _newSession();
  final _boardKey = GlobalKey();

  int? _hoverTray;
  Cell? _hoverOrigin;
  bool _hoverValid = false;

  // One-shot flash of whatever just got cleared, so the player sees the
  // lines disappear instead of just vanishing between frames.
  Map<int, int>? _flashCells;
  int _flashGeneration = 0;

  bool _finished = false;
  GameOutcome? _outcome;

  GameSession _newSession() => widget.mode == GameMode.daily
      ? GameSession.seeded(DailyChallenge.seedFor(_day),
          boardSize: DailyChallenge.boardSize)
      : GameSession.classic();

  void _restart() {
    setState(() {
      _day = widget.day ?? DateTime.now();
      _session = _newSession();
      _finished = false;
      _outcome = null;
      _hoverTray = null;
      _hoverOrigin = null;
      _flashCells = null;
    });
  }

  /// Converts a global pointer position to a board cell, or null if it's
  /// nowhere near the board.
  Cell? _cellFromGlobal(Offset global, double cellSize) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    const slack = .6; // cells of wiggle room outside the exact box
    if (local.dx < -slack * cellSize ||
        local.dy < -slack * cellSize ||
        local.dx > box.size.width + slack * cellSize ||
        local.dy > box.size.height + slack * cellSize) {
      return null;
    }
    final x = (local.dx / cellSize).floor();
    final y = (local.dy / cellSize).floor();
    return Cell(x, y);
  }

  void _updateHover(int trayIndex, Offset global, double cellSize) {
    final cell = _cellFromGlobal(global, cellSize);
    if (cell == null) {
      _clearHover();
      return;
    }
    final valid = _session.canPlace(trayIndex, cell.x, cell.y);
    if (_hoverTray == trayIndex && _hoverOrigin == cell && _hoverValid == valid) {
      return;
    }
    setState(() {
      _hoverTray = trayIndex;
      _hoverOrigin = cell;
      _hoverValid = valid;
    });
  }

  void _clearHover() {
    if (_hoverOrigin == null && _hoverTray == null) return;
    setState(() {
      _hoverTray = null;
      _hoverOrigin = null;
    });
  }

  void _drop(int trayIndex, Offset global, double cellSize) {
    final cell = _cellFromGlobal(global, cellSize);
    _clearHover();
    if (cell == null || _finished) return;
    final result = _session.place(trayIndex, cell.x, cell.y);
    if (result == null) return;

    final app = AppState.instance;
    if (app.hapticsOn) {
      result.cleared
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.lightImpact();
    }
    Sound.instance.play(result.cleared ? SoundEffect.clear : SoundEffect.place);
    if (result.comboAfter >= 2) Sound.instance.play(SoundEffect.combo);

    setState(() {
      if (result.cleared) {
        _flashGeneration++;
        _flashCells = result.clearedCellColors;
      }
    });

    if (_session.gameOver) {
      Future<void>.delayed(const Duration(milliseconds: 320), _finish);
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    final outcome = AppState.instance.recordGameResult(
      mode: _session.mode,
      score: _session.score,
      linesCleared: _session.linesClearedTotal,
      movesPlayed: _session.movesPlayed,
      day: _day,
    );
    Sound.instance.play(SoundEffect.gameOver);
    setState(() {
      _finished = true;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppState.instance.theme;
    final skin = AppState.instance.skin;
    final size = _session.board.size;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Hud(
                  session: _session,
                  theme: t,
                  title: widget.mode == GameMode.daily
                      ? 'Daily Challenge'
                      : 'Classic',
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final trayReserve = constraints.maxHeight * .24;
                      final boardMax = (constraints.maxHeight - trayReserve)
                          .clamp(100.0, double.infinity);
                      final side = constraints.maxWidth < boardMax
                          ? constraints.maxWidth
                          : boardMax;
                      final boardSide = side * .94;
                      final cellSize = boardSide / size;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: boardSide,
                            height: boardSide,
                            child: _BoardView(
                              key: _boardKey,
                              session: _session,
                              skin: skin,
                              theme: t,
                              cellSize: cellSize,
                              hoverShape:
                                  _hoverTray == null ? null : _session.tray[_hoverTray!],
                              hoverOrigin: _hoverOrigin,
                              hoverValid: _hoverValid,
                              flashCells: _flashCells,
                              flashKey: ValueKey(_flashGeneration),
                              onFlashDone: () =>
                                  setState(() => _flashCells = null),
                            ),
                          ),
                          SizedBox(height: boardSide * .05),
                          _Tray(
                            session: _session,
                            skin: skin,
                            theme: t,
                            previewCellSize: cellSize * .52,
                            onDragUpdate: (i, g) =>
                                _updateHover(i, g, cellSize),
                            onDragEnd: (i, g) => _drop(i, g, cellSize),
                            onDragCanceled: _clearHover,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_finished)
              _GameOverSheet(
                session: _session,
                outcome: _outcome,
                theme: t,
                onRetry: _restart,
                onHome: () => Navigator.of(context).maybePop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.session, required this.theme, required this.title});

  final GameSession session;
  final AppTheme theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.text),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: theme.subtext,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('${session.score}',
                    style: TextStyle(
                        color: theme.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (session.combo >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.gold.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Combo x${session.combo}',
                  style: TextStyle(
                      color: theme.gold, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView({
    super.key,
    required this.session,
    required this.skin,
    required this.theme,
    required this.cellSize,
    required this.hoverShape,
    required this.hoverOrigin,
    required this.hoverValid,
    required this.flashCells,
    required this.flashKey,
    required this.onFlashDone,
  });

  final GameSession session;
  final BlockSkin skin;
  final AppTheme theme;
  final double cellSize;
  final PieceShape? hoverShape;
  final Cell? hoverOrigin;
  final bool hoverValid;
  final Map<int, int>? flashCells;
  final Key flashKey;
  final VoidCallback onFlashDone;

  @override
  Widget build(BuildContext context) {
    final board = session.board;
    final size = board.size;
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BoardBackgroundPainter(
                size_: size,
                panelColor: theme.surface,
                lineColor: theme.line,
                checkerA: theme.checkerA,
                checkerB: theme.checkerB,
              ),
            ),
          ),
          for (var y = 0; y < size; y++)
            for (var x = 0; x < size; x++)
              if (board.colorAt(x, y) != -1)
                Positioned(
                  left: x * cellSize,
                  top: y * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: BlockTile(
                      color: skin.forPiece(
                          PieceColor.values[board.colorAt(x, y)])),
                ),
          if (hoverShape != null && hoverOrigin != null)
            IgnorePointer(
              child: Stack(
                children: [
                  for (final c in hoverShape!.cells)
                    if (board.inBounds(
                        hoverOrigin!.x + c.x, hoverOrigin!.y + c.y))
                      Positioned(
                        left: (hoverOrigin!.x + c.x) * cellSize,
                        top: (hoverOrigin!.y + c.y) * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: hoverValid
                            ? BlockTile(
                                color: skin.forPiece(hoverShape!.color),
                                opacity: .55)
                            : const BlockTile(
                                color: Colors.red, opacity: .85, outlineOnly: true),
                      ),
                ],
              ),
            ),
          if (flashCells != null && flashCells!.isNotEmpty)
            TweenAnimationBuilder<double>(
              key: flashKey,
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              onEnd: onFlashDone,
              builder: (context, t, _) => IgnorePointer(
                child: Opacity(
                  opacity: (1 - t).clamp(0, 1),
                  child: Stack(
                    children: [
                      for (final entry in flashCells!.entries)
                        Positioned(
                          left: (entry.key % size) * cellSize,
                          top: (entry.key ~/ size) * cellSize,
                          width: cellSize,
                          height: cellSize,
                          child: Transform.scale(
                            scale: 1 + t * .35,
                            child: BlockTile(
                                color: skin.forPiece(
                                    PieceColor.values[entry.value])),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.session,
    required this.skin,
    required this.theme,
    required this.previewCellSize,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCanceled,
  });

  final GameSession session;
  final BlockSkin skin;
  final AppTheme theme;
  final double previewCellSize;
  final void Function(int trayIndex, Offset global) onDragUpdate;
  final void Function(int trayIndex, Offset global) onDragEnd;
  final VoidCallback onDragCanceled;

  @override
  Widget build(BuildContext context) {
    final slot = previewCellSize * 5.2;
    return SizedBox(
      height: slot,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < session.tray.length; i++)
            SizedBox(
              width: slot,
              height: slot,
              child: _TraySlot(
                shape: session.tray[i],
                skin: skin,
                theme: theme,
                previewCellSize: previewCellSize,
                onDragUpdate: (g) => onDragUpdate(i, g),
                onDragEnd: (g) => onDragEnd(i, g),
                onDragCanceled: onDragCanceled,
              ),
            ),
        ],
      ),
    );
  }
}

class _TraySlot extends StatelessWidget {
  const _TraySlot({
    required this.shape,
    required this.skin,
    required this.theme,
    required this.previewCellSize,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCanceled,
  });

  final PieceShape? shape;
  final BlockSkin skin;
  final AppTheme theme;
  final double previewCellSize;
  final void Function(Offset global) onDragUpdate;
  final void Function(Offset global) onDragEnd;
  final VoidCallback onDragCanceled;

  Widget _grid(PieceShape s, double cellSize, {double opacity = 1}) => SizedBox(
        width: s.width * cellSize,
        height: s.height * cellSize,
        child: Stack(
          children: [
            for (final c in s.cells)
              Positioned(
                left: c.x * cellSize,
                top: c.y * cellSize,
                width: cellSize,
                height: cellSize,
                child: BlockTile(color: skin.forPiece(s.color), opacity: opacity),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = shape;
    if (s == null) {
      return Center(
        child: Container(
          width: previewCellSize * 2,
          height: previewCellSize * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.line.withValues(alpha: .4),
          ),
        ),
      );
    }
    return Center(
      // No `data`/`DragTarget` plumbing: which tray slot is being dragged is
      // already captured by the closures below, and the drop cell is read
      // straight off the pointer position in `onDragEnd`.
      child: Draggable<Object>(
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _grid(s, previewCellSize * 1.8, opacity: .95),
        childWhenDragging: _grid(s, previewCellSize, opacity: .25),
        onDragUpdate: (d) => onDragUpdate(d.globalPosition),
        onDragEnd: (d) => onDragEnd(d.offset),
        onDraggableCanceled: (_, __) => onDragCanceled(),
        child: _grid(s, previewCellSize),
      ),
    );
  }
}

class _GameOverSheet extends StatelessWidget {
  const _GameOverSheet({
    required this.session,
    required this.outcome,
    required this.theme,
    required this.onRetry,
    required this.onHome,
  });

  final GameSession session;
  final GameOutcome? outcome;
  final AppTheme theme;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: .55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No more moves',
                    style: TextStyle(
                        color: theme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('${session.score}',
                    style: TextStyle(
                        color: theme.accent,
                        fontSize: 40,
                        fontWeight: FontWeight.w900)),
                if (o?.isNewBest ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('New best!',
                        style: TextStyle(
                            color: theme.gold, fontWeight: FontWeight.w700)),
                  ),
                if (o != null && o.coinsEarned > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on, color: theme.gold, size: 18),
                        const SizedBox(width: 4),
                        Text('+${o.coinsEarned}',
                            style: TextStyle(
                                color: theme.gold, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onHome,
                        child: const Text('Home'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onRetry,
                        child: const Text('Play again'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

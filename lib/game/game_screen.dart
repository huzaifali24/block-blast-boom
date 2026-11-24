import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/sound.dart';
import '../app/theme.dart';
import '../ui/widgets.dart';
import 'board_painter.dart';
import 'engine.dart';
import 'modes.dart';
import 'session.dart';
import 'skins.dart';

/// The playable screen: score HUD, board, the three-piece tray, and the
/// game-over flow. Works for both [GameMode.classic] and [GameMode.daily] —
/// only how the [GameSession] is seeded differs.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode, this.day});

  final GameMode mode;

  /// Which calendar day's board to play. Required for [GameMode.daily];
  /// ignored otherwise. Defaults to today.
  final DateTime? day;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _FlyBack {
  _FlyBack(this.index, this.from, this.to, this.gen);
  final int index;
  final Offset from; // piece center, root-local
  final Offset to;
  final int gen;
}

class _Popup {
  _Popup(this.text, this.sub, this.gen);
  final String text;
  final String? sub;
  final int gen;
}

class _ScorePop {
  _ScorePop(this.text, this.at, this.gen);
  final String text;
  final Offset at; // board-local
  final int gen;
}

class _GameScreenState extends State<GameScreen> {
  late DateTime _day = widget.day ?? DateTime.now();
  late GameSession _session = _newSession();
  final _rng = math.Random();

  final _rootKey = GlobalKey();
  final _gridKey = GlobalKey();
  final _slotKeys = List.generate(3, (_) => GlobalKey());

  // Layout, refreshed every build.
  double _cell = 32;
  double _trayCell = 16;

  // Dragging.
  int? _dragIndex;
  int? _pointer;
  Offset _pointerPos = Offset.zero; // root-local
  int _dragGen = 0;
  Cell? _ghost;
  List<int> _previewRows = const [];
  List<int> _previewCols = const [];
  _FlyBack? _flyBack;

  // Effects.
  int _gen = 0;
  int _trayGen = 0;
  Set<int> _popCells = const {};
  List<ClearingCell> _clearing = const [];
  List<Particle> _particles = const [];
  _Popup? _praise;
  _ScorePop? _scorePop;
  int _shakeGen = 0;
  double _shakeAmp = 0;

  // Game over.
  bool _over = false;
  bool _showResults = false;
  int _overGen = 0;
  GameOutcome? _outcome;

  GameSession _newSession() => widget.mode == GameMode.daily
      ? GameSession.seeded(DailyChallenge.seedFor(_day),
          boardSize: DailyChallenge.boardSize)
      : GameSession.classic();

  void _restart() {
    setState(() {
      _day = widget.day ?? DateTime.now();
      _session = _newSession();
      _dragIndex = null;
      _pointer = null;
      _ghost = null;
      _previewRows = const [];
      _previewCols = const [];
      _flyBack = null;
      _popCells = const {};
      _clearing = const [];
      _particles = const [];
      _praise = null;
      _scorePop = null;
      _over = false;
      _showResults = false;
      _outcome = null;
      _gen++;
      _trayGen++;
      _overGen++;
    });
  }

  // ---------------------------------------------------------------- geometry

  RenderBox? get _rootBox =>
      _rootKey.currentContext?.findRenderObject() as RenderBox?;

  Offset _toRoot(Offset global) => _rootBox?.globalToLocal(global) ?? global;

  Offset? _gridOrigin() {
    final g = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    final r = _rootBox;
    if (g == null || r == null || !g.attached) return null;
    return g.localToGlobal(Offset.zero, ancestor: r);
  }

  Offset _slotCenter(int i) {
    final b = _slotKeys[i].currentContext?.findRenderObject() as RenderBox?;
    final r = _rootBox;
    if (b == null || r == null) return _pointerPos;
    return b.localToGlobal(b.size.center(Offset.zero), ancestor: r);
  }

  /// Where the dragged piece's top-left corner sits (root-local) for a lift
  /// progress [k]: centered on the finger at 0, floating fully above it at 1
  /// so the finger never hides where the piece will land.
  Offset _pieceTopLeft(PieceShape s, double k, double cell) {
    final w = s.width * cell, h = s.height * cell;
    final centered = Offset(-w / 2, -h / 2);
    final lifted = Offset(-w / 2, -h - _cell * .9);
    return _pointerPos + Offset.lerp(centered, lifted, k)!;
  }

  void _updateGhost() {
    final i = _dragIndex;
    final s = i == null ? null : _session.tray[i];
    final origin = _gridOrigin();
    if (s == null || origin == null) {
      _clearGhost();
      return;
    }
    final tl = _pieceTopLeft(s, 1, _cell) - origin;
    final ox = (tl.dx / _cell).round();
    final oy = (tl.dy / _cell).round();
    if (!_session.board.canPlace(s, ox, oy)) {
      _clearGhost();
      return;
    }
    final g = Cell(ox, oy);
    if (g == _ghost) return;
    _ghost = g;
    final sim = _session.board.clone()..place(s, ox, oy, s.color.index);
    final lines = sim.fullLines();
    _previewRows = lines.rows;
    _previewCols = lines.cols;
  }

  void _clearGhost() {
    _ghost = null;
    _previewRows = const [];
    _previewCols = const [];
  }

  // ------------------------------------------------------------------ input

  void _onDown(int i, PointerDownEvent e) {
    if (_dragIndex != null || _over || _session.tray[i] == null) return;
    if (_flyBack?.index == i) return;
    _pointer = e.pointer;
    setState(() {
      _dragIndex = i;
      _dragGen++;
      _pointerPos = _toRoot(e.position);
      _updateGhost();
    });
    Sound.instance.play(SoundEffect.pick);
    if (AppState.instance.hapticsOn) HapticFeedback.selectionClick();
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _dragIndex == null) return;
    setState(() {
      _pointerPos = _toRoot(e.position);
      _updateGhost();
    });
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _release();
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _release(cancelled: true);
  }

  void _release({bool cancelled = false}) {
    final i = _dragIndex;
    _pointer = null;
    if (i == null) return;
    final ghost = _ghost;
    if (!cancelled && ghost != null && _session.canPlace(i, ghost.x, ghost.y)) {
      _place(i, ghost);
      return;
    }
    final s = _session.tray[i];
    setState(() {
      if (s != null) {
        final tl = _pieceTopLeft(s, 1, _cell);
        _flyBack = _FlyBack(
          i,
          tl + Offset(s.width * _cell / 2, s.height * _cell / 2),
          _slotCenter(i),
          ++_gen,
        );
      }
      _dragIndex = null;
      _clearGhost();
    });
  }

  // -------------------------------------------------------------- placement

  void _place(int i, Cell at) {
    final shape = _session.tray[i]!;
    final lastOfTray = _session.tray.where((s) => s != null).length == 1;
    final result = _session.place(i, at.x, at.y);
    if (result == null) return;

    final skin = AppState.instance.skin;
    final n = _session.board.size;
    final placed = {
      for (final c in shape.cells) (at.y + c.y) * n + at.x + c.x,
    };
    var cx = 0.0, cy = 0.0;
    for (final c in shape.cells) {
      cx += (at.x + c.x + .5) * _cell;
      cy += (at.y + c.y + .5) * _cell;
    }
    final center = Offset(cx / shape.cellCount, cy / shape.cellCount);

    setState(() {
      _gen++;
      _dragIndex = null;
      _clearGhost();
      _popCells = placed.difference(result.clearedCells);
      if (lastOfTray) _trayGen++;
      _scorePop = _ScorePop('+${result.points}', center, _gen);

      if (result.cleared) {
        final fx = buildClearFx(
          cleared: result.clearedCellColors,
          boardSize: n,
          cell: _cell,
          from: center,
          skin: skin,
          rng: _rng,
        );
        _clearing = fx.cells;
        _particles = fx.particles;
        _praise = _praiseFor(result);
        if (result.linesCleared >= 3 || result.allClear) {
          _shakeGen++;
          _shakeAmp = _cell * (result.allClear ? .22 : .12);
        }
      }
    });

    final haptics = AppState.instance.hapticsOn;
    if (result.cleared) {
      final big = result.linesCleared >= 2 || result.comboAfter >= 2;
      Sound.instance.play(big ? SoundEffect.combo : SoundEffect.clear);
      if (haptics) {
        result.linesCleared >= 3
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.mediumImpact();
      }
    } else {
      Sound.instance.play(SoundEffect.place);
      if (haptics) HapticFeedback.lightImpact();
    }

    if (_session.gameOver) {
      Future<void>.delayed(const Duration(milliseconds: 650), _startGameOver);
    }
  }

  _Popup? _praiseFor(PlacementResult r) {
    final combo = r.comboAfter;
    final sub = combo >= 2 ? 'Combo $combo' : null;
    if (r.allClear) return _Popup('All Clear!', sub ?? '+${ScoreRules.allClearBonus}', _gen);
    final level = r.linesCleared + (combo - 1);
    const words = ['Good!', 'Great!', 'Excellent!', 'Amazing!', 'Unbelievable!'];
    if (level < 2) return sub == null ? null : _Popup(sub, null, _gen);
    return _Popup(words[math.min(level - 2, words.length - 1)], sub, _gen);
  }

  void _startGameOver() {
    if (_over || !mounted) return;
    final outcome = AppState.instance.recordGameResult(
      mode: _session.mode,
      score: _session.score,
      linesCleared: _session.linesClearedTotal,
      movesPlayed: _session.movesPlayed,
      day: _day,
    );
    Sound.instance.play(SoundEffect.gameOver);
    if (AppState.instance.hapticsOn) HapticFeedback.heavyImpact();
    setState(() {
      _over = true;
      _overGen++;
      _outcome = outcome;
    });
    final gen = _overGen;
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (mounted && _over && _overGen == gen) {
        setState(() => _showResults = true);
      }
    });
  }

  int get _best {
    final app = AppState.instance;
    final stored = widget.mode == GameMode.daily
        ? app.bestDailyFor(_day)
        : app.bestClassic;
    return math.max(stored, _session.score);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final t = AppState.instance.theme;
    final skin = AppState.instance.skin;
    final n = _session.board.size;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.backgroundGradient),
        child: SafeArea(
          child: Stack(
            key: _rootKey,
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  _hud(t),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      final outer = math.min(c.maxWidth - 20, c.maxHeight * .66);
                      final pad = outer * .025;
                      final grid = outer - pad * 2;
                      _cell = grid / n;
                      _trayCell = _cell * .5;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _board(t, skin, outer, pad, grid),
                          _tray(skin, c.maxWidth),
                        ],
                      );
                    }),
                  ),
                ],
              ),
              if (_dragIndex != null) _draggedPiece(skin),
              if (_flyBack != null) _flyBackPiece(skin),
              if (_showResults) _results(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: t.gold, size: 28),
              const SizedBox(width: 6),
              Text('$_best',
                  style: TextStyle(
                      fontFamily: kFont,
                      color: t.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              if (widget.mode == GameMode.daily)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text('DAILY',
                      style: TextStyle(
                          fontFamily: kFont,
                          color: t.subtext,
                          fontSize: 13,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800)),
                ),
              _RoundIconButton(
                icon: Icons.settings_rounded,
                color: t.surface,
                onTap: () => _openPause(t),
              ),
            ],
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _session.score.toDouble()),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (_, v, __) => ArcadeText(
              '${v.round()}',
              size: 54,
              colors: const [Colors.white, Color(0xFFD9DEFF)],
              stroke: t.boardFrame,
            ),
          ),
        ],
      ),
    );
  }

  Widget _board(AppTheme t, BlockSkin skin, double outer, double pad, double grid) {
    final dragShape = _dragIndex == null ? null : _session.tray[_dragIndex!];
    return TweenAnimationBuilder<double>(
      key: ValueKey('shake$_shakeGen'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, s, child) => Transform.translate(
        offset: Offset(math.sin(s * math.pi * 8) * (1 - s) * _shakeAmp, 0),
        child: child,
      ),
      child: Container(
        width: outer,
        height: outer,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: t.boardFrame,
          borderRadius: BorderRadius.circular(outer * .035),
          border: Border.all(
              color: Color.lerp(t.boardFrame, Colors.white, .1)!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SizedBox(
          key: _gridKey,
          width: grid,
          height: grid,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('pop$_gen'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 260),
                  builder: (_, popT, __) => TweenAnimationBuilder<double>(
                    key: ValueKey('grey$_overGen'),
                    tween: Tween(begin: 0, end: _over ? 1 : 0),
                    duration: const Duration(milliseconds: 900),
                    builder: (_, greyT, __) => CustomPaint(
                      painter: BoardPainter(
                        board: _session.board,
                        skin: skin,
                        theme: t,
                        ghostShape: _ghost == null ? null : dragShape,
                        ghostOrigin: _ghost,
                        ghostColor: dragShape == null
                            ? null
                            : skin.forPiece(dragShape.color),
                        previewRows: _previewRows,
                        previewCols: _previewCols,
                        popCells: _popCells,
                        popT: popT,
                        greyT: greyT,
                      ),
                    ),
                  ),
                ),
              ),
              if (_clearing.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('clear$_gen'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 800),
                      onEnd: () => setState(() {
                        _clearing = const [];
                        _particles = const [];
                      }),
                      builder: (_, k, __) => CustomPaint(
                        painter: ClearFxPainter(
                          cells: _clearing,
                          particles: _particles,
                          cell: _cell,
                          t: k,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_scorePop != null) _scorePopWidget(_scorePop!),
              if (_praise != null) _praiseWidget(_praise!, grid),
              if (_over && !_showResults)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('nospace$_overGen'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: const Interval(.4, 1, curve: Curves.easeOutBack),
                        builder: (_, k, child) => Opacity(
                          opacity: k.clamp(0, 1),
                          child: Transform.scale(scale: .6 + .4 * k, child: child),
                        ),
                        child: ArcadeText('No More Space', size: _cell * .8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scorePopWidget(_ScorePop p) {
    return Positioned(
      left: p.at.dx - 120,
      top: p.at.dy - 40,
      width: 240,
      height: 80,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('score${p.gen}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 750),
          onEnd: () {
            if (_scorePop?.gen == p.gen) setState(() => _scorePop = null);
          },
          builder: (_, k, child) => Transform.translate(
            offset: Offset(0, -_cell * 1.1 * Curves.easeOut.transform(k)),
            child: Opacity(
              opacity: k < .6 ? 1 : (1 - (k - .6) / .4),
              child: child,
            ),
          ),
          child: Center(
            child: ArcadeText(p.text,
                size: _cell * .55,
                colors: const [Colors.white, Color(0xFFE3E7FF)],
                stroke: const Color(0xFF15164C)),
          ),
        ),
      ),
    );
  }

  Widget _praiseWidget(_Popup p, double grid) {
    return Positioned(
      left: -grid * .1,
      right: -grid * .1,
      top: grid * .28,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('praise${p.gen}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1250),
          onEnd: () {
            if (_praise?.gen == p.gen) setState(() => _praise = null);
          },
          builder: (_, k, child) {
            final inK = Curves.elasticOut.transform((k / .35).clamp(0, 1));
            final out = k < .75 ? 0.0 : (k - .75) / .25;
            return Transform.translate(
              offset: Offset(0, -_cell * .8 * out),
              child: Opacity(
                opacity: 1 - out,
                child: Transform.scale(scale: .3 + .7 * inK, child: child),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArcadeText(p.text, size: _cell * (p.text.length > 10 ? .85 : 1.05)),
              if (p.sub != null)
                ArcadeText(p.sub!,
                    size: _cell * .5,
                    colors: const [Color(0xFFB8F7FF), Color(0xFF3FC3F2)],
                    stroke: const Color(0xFF0B2350)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tray(BlockSkin skin, double width) {
    final slotH = _trayCell * 5 + 16;
    return SizedBox(
      height: slotH,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            SizedBox(
              key: _slotKeys[i],
              width: width / 3,
              height: slotH,
              child: _slot(i, skin),
            ),
        ],
      ),
    );
  }

  Widget _slot(int i, BlockSkin skin) {
    final s = _session.tray[i];
    final hidden = s == null || _dragIndex == i || _flyBack?.index == i;
    Widget child = const SizedBox.expand();
    if (!hidden) {
      final fits = _over || _session.board.canPlaceAnywhere(s);
      child = Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('deal$_trayGen-$i'),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 380 + i * 90),
          curve: Interval(i * .18, 1, curve: Curves.easeOutBack),
          builder: (_, k, child) => Transform.scale(scale: k, child: child),
          child: CustomPaint(
            size: Size(s.width * _trayCell, s.height * _trayCell),
            painter: PiecePainter(
              shape: s,
              color: skin.forPiece(s.color),
              cell: _trayCell,
              opacity: fits ? 1 : .35,
            ),
          ),
        ),
      );
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _onDown(i, e),
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: child,
    );
  }

  Widget _draggedPiece(BlockSkin skin) {
    final s = _session.tray[_dragIndex!];
    if (s == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey('lift$_dragGen'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      builder: (_, k, __) {
        final cell = lerpDouble(_trayCell, _cell, k)!;
        final tl = _pieceTopLeft(s, k, cell);
        return Positioned(
          left: tl.dx,
          top: tl.dy,
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(s.width * cell, s.height * cell),
              painter: PiecePainter(
                  shape: s, color: skin.forPiece(s.color), cell: cell),
            ),
          ),
        );
      },
    );
  }

  Widget _flyBackPiece(BlockSkin skin) {
    final f = _flyBack!;
    final s = _session.tray[f.index];
    if (s == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey('fly${f.gen}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (_flyBack?.gen == f.gen) setState(() => _flyBack = null);
      },
      builder: (_, k, __) {
        final cell = lerpDouble(_cell, _trayCell, k)!;
        final c = Offset.lerp(f.from, f.to, k)!;
        final w = s.width * cell, h = s.height * cell;
        return Positioned(
          left: c.dx - w / 2,
          top: c.dy - h / 2,
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(w, h),
              painter: PiecePainter(
                  shape: s, color: skin.forPiece(s.color), cell: cell),
            ),
          ),
        );
      },
    );
  }

  Widget _results(AppTheme t) {
    final o = _outcome;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        builder: (_, k, child) => ColoredBox(
          color: Colors.black.withValues(alpha: .62 * k),
          child: Opacity(
            opacity: k,
            child: Transform.scale(
              scale: .85 + .15 * Curves.easeOutBack.transform(k),
              child: child,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (o?.isNewBest ?? false)
                const ArcadeText('New Best!', size: 44)
              else
                Text('SCORE',
                    style: TextStyle(
                        fontFamily: kFont,
                        color: t.subtext,
                        fontSize: 20,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ArcadeText('${_session.score}',
                  size: 72,
                  colors: const [Colors.white, Color(0xFFD9DEFF)],
                  stroke: t.boardFrame),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, color: t.gold, size: 24),
                  const SizedBox(width: 6),
                  Text('Best  $_best',
                      style: TextStyle(
                          fontFamily: kFont,
                          color: t.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              if (o != null && o.coinsEarned > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on_rounded, color: t.gold, size: 22),
                    const SizedBox(width: 6),
                    Text('+${o.coinsEarned}',
                        style: TextStyle(
                            fontFamily: kFont,
                            color: t.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              ChunkyButton(
                color: t.accent,
                width: 250,
                onPressed: _restart,
                child: const _ButtonLabel(Icons.replay_rounded, 'Play Again'),
              ),
              const SizedBox(height: 14),
              ChunkyButton(
                color: const Color(0xFF5865F2),
                width: 250,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const _ButtonLabel(Icons.home_rounded, 'Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPause(AppTheme t) {
    Sound.instance.play(SoundEffect.tap);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .6),
      builder: (ctx) => Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: ListenableBuilder(
            listenable: AppState.instance,
            builder: (ctx, _) {
              final app = AppState.instance;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ArcadeText('Paused', size: 36),
                  const SizedBox(height: 18),
                  _ToggleRow(
                    icon: Icons.volume_up_rounded,
                    label: 'Sound',
                    value: app.soundOn,
                    theme: t,
                    onChanged: app.setSoundOn,
                  ),
                  _ToggleRow(
                    icon: Icons.vibration_rounded,
                    label: 'Vibration',
                    value: app.hapticsOn,
                    theme: t,
                    onChanged: app.setHapticsOn,
                  ),
                  const SizedBox(height: 18),
                  ChunkyButton(
                    color: t.accent,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const _ButtonLabel(Icons.play_arrow_rounded, 'Resume'),
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton(
                    color: const Color(0xFFFF8A26),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _restart();
                    },
                    child: const _ButtonLabel(Icons.replay_rounded, 'Restart'),
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton(
                    color: const Color(0xFF5865F2),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).maybePop();
                    },
                    child: const _ButtonLabel(Icons.home_rounded, 'Home'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: kFont,
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
        ],
      );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChunkyButton(
        color: color,
        width: 46,
        height: 42,
        radius: 14,
        onPressed: onTap,
        child: Icon(icon, color: Colors.white, size: 26),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final AppTheme theme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: theme.text),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: kFont,
                    color: theme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: theme.accent,
            onChanged: onChanged,
          ),
        ],
      );
}

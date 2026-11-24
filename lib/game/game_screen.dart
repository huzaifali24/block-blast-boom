import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/music.dart';
import '../app/sound.dart';
import '../app/theme.dart';
import '../ui/fx.dart';
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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _day = widget.day ?? DateTime.now();
  late GameSession _session = _newSession();
  final _rng = math.Random();

  final _rootKey = GlobalKey();
  final _gridKey = GlobalKey();
  final _slotKeys = List.generate(3, (_) => GlobalKey());

  /// Loops while dragging so preview lines shimmer.
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

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
  ClearFx? _clearFx;
  _Popup? _praise;
  _ScorePop? _scorePop;
  int _shakeGen = 0;
  double _shakeAmp = 0;
  int _flashGen = 0;
  double _flashStrength = 0;

  // Game over.
  bool _over = false;
  bool _showResults = false;
  int _overGen = 0;
  GameOutcome? _outcome;

  @override
  void dispose() {
    Music.instance.duck(false);
    _pulse.dispose();
    super.dispose();
  }



  GameSession _newSession() => widget.mode == GameMode.daily
      ? GameSession.seeded(DailyChallenge.seedFor(_day),
          boardSize: DailyChallenge.boardSize)
      : GameSession.classic();

  void _restart() {
    _pulse.stop();
    Music.instance.duck(false);
    setState(() {
      _day = widget.day ?? DateTime.now();
      _session = _newSession();
      _dragIndex = null;
      _pointer = null;
      _clearGhost();
      _flyBack = null;
      _popCells = const {};
      _clearFx = null;
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
    if ((_previewRows.isNotEmpty || _previewCols.isNotEmpty) &&
        AppState.instance.hapticsOn) {
      HapticFeedback.selectionClick();
    }
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
    _pulse.repeat();
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
    _pulse.stop();
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
        _clearFx = buildClearFx(
          result: result,
          boardSize: n,
          cell: _cell,
          from: center,
          skin: skin,
          rng: _rng,
        );
        _praise = _praiseFor(result);
        if (result.linesCleared >= 3 || result.allClear) {
          _shakeGen++;
          _shakeAmp = _cell * (result.allClear ? .22 : .12);
        }
        if (result.linesCleared >= 2 || result.allClear) {
          _flashGen++;
          _flashStrength = result.allClear ? .55 : .12 + .06 * result.linesCleared;
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
    final sub = combo >= 2 ? 'Combo x$combo' : null;
    if (r.allClear) {
      return _Popup('All Clear!', sub ?? '+${ScoreRules.allClearBonus}', _gen);
    }
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
    Music.instance.duck(true);
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
        if (outcome.isNewBest) Sound.instance.play(SoundEffect.coin);
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
      backgroundColor: t.background,
      body: AmbientBackground(
        theme: t,
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
                      // The tray is ~3.3 board cells tall; size the board so
                      // board + tray + minimum breathing room always fit.
                      const trayCells = 3.3;
                      final byHeight =
                          (c.maxHeight - 36) / (1 + trayCells * .94 / n);
                      final outer = math.min(c.maxWidth - 16, byHeight);
                      final pad = outer * .03;
                      final grid = outer - pad * 2;
                      _cell = grid / n;
                      _trayCell =
                          math.min(_cell * .6, (c.maxWidth / 3 - 16) / 5);
                      return Column(
                        children: [
                          const Spacer(flex: 2),
                          _board(t, skin, outer, pad, grid),
                          const Spacer(flex: 3),
                          _tray(t, skin, c.maxWidth, _cell * trayCells),
                          const Spacer(flex: 1),
                        ],
                      );
                    }),
                  ),
                ],
              ),
              if (_dragIndex != null) _draggedPiece(skin),
              if (_flyBack != null) _flyBackPiece(skin),
              if (_flashGen > 0) _flash(),
              if (_showResults) _results(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud(AppTheme t) {
    final daily = widget.mode == GameMode.daily;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              _BestBadge(best: _best, theme: t),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: _session.combo >= 2
                        ? _ComboBadge(
                            key: ValueKey(_session.combo), combo: _session.combo)
                        : daily
                            ? const _DailyTag()
                            : const SizedBox.shrink(),
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.pause_rounded,
                color: Color.lerp(t.surface, Colors.white, .12)!,
                onTap: () => _openPause(t),
              ),
            ],
          ),
          SizedBox(
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Soft glow behind the score.
                Container(
                  width: 280,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      const Color(0xFF9FB0FF).withValues(alpha: .32),
                      const Color(0xFF9FB0FF).withValues(alpha: 0),
                    ]),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _session.score.toDouble()),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => ArcadeText(
                    '${v.round()}',
                    size: 60,
                    colors: const [Colors.white, Color(0xFFD9DEFF)],
                    stroke: t.boardFrame,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _board(AppTheme t, BlockSkin skin, double outer, double pad, double grid) {
    final dragShape = _dragIndex == null ? null : _session.tray[_dragIndex!];
    final radius = outer * .045;
    return TweenAnimationBuilder<double>(
      key: ValueKey('shake$_shakeGen'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, s, child) => Transform.translate(
        offset: Offset(math.sin(s * math.pi * 8) * (1 - s) * _shakeAmp,
            math.cos(s * math.pi * 6) * (1 - s) * _shakeAmp * .4),
        child: child,
      ),
      // Outer bevelled rim: lit from above, dark underneath.
      child: Container(
        width: outer,
        height: outer,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius + 3),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(t.boardFrame, Colors.white, .35)!,
              Color.lerp(t.boardFrame, Colors.white, .08)!,
              Color.lerp(t.boardFrame, Colors.black, .35)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .45),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: const Color(0xFF7C8CFF).withValues(alpha: .18),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          padding: EdgeInsets.all(pad - 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(t.boardFrame, Colors.black, .25)!,
                t.boardFrame,
              ],
            ),
          ),
          child: SizedBox(
            key: _gridKey,
            width: grid,
            height: grid,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => TweenAnimationBuilder<double>(
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
                              pulse: _pulse.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_clearFx != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('clear$_gen'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 850),
                        onEnd: () => setState(() => _clearFx = null),
                        builder: (_, k, __) => CustomPaint(
                          painter: ClearFxPainter(fx: _clearFx!, cell: _cell, t: k),
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
                          child: ArcadeText('No More Space',
                              size: _cell * .8,
                              colors: const [Color(0xFFFFB3B3), Color(0xFFFF4D5E)],
                              stroke: const Color(0xFF3D0610)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _flash() {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('flash$_flashGen'),
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOut,
          builder: (_, k, __) => k <= 0
              ? const SizedBox.shrink()
              : ColoredBox(color: Colors.white.withValues(alpha: _flashStrength * k)),
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
          duration: const Duration(milliseconds: 800),
          onEnd: () {
            if (_scorePop?.gen == p.gen) setState(() => _scorePop = null);
          },
          builder: (_, k, child) => Transform.translate(
            offset: Offset(0, -_cell * 1.2 * Curves.easeOut.transform(k)),
            child: Opacity(
              opacity: k < .6 ? 1 : (1 - (k - .6) / .4),
              child: Transform.scale(
                  scale: .7 + .3 * Curves.easeOutBack.transform((k / .3).clamp(0, 1)),
                  child: child),
            ),
          ),
          child: Center(
            child: ArcadeText(p.text,
                size: _cell * .58,
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
      top: grid * .26,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('praise${p.gen}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1300),
          onEnd: () {
            if (_praise?.gen == p.gen) setState(() => _praise = null);
          },
          builder: (_, k, child) {
            final inK = Curves.elasticOut.transform((k / .38).clamp(0, 1));
            final out = k < .75 ? 0.0 : (k - .75) / .25;
            return Transform.translate(
              offset: Offset(0, -_cell * .8 * out),
              child: Opacity(
                opacity: 1 - out,
                child: Transform.rotate(
                  angle: (1 - inK) * -.15,
                  child: Transform.scale(scale: .3 + .7 * inK, child: child),
                ),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                child: Container(
                  width: grid * 1.1,
                  height: _cell * 3,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      const Color(0xFFFFB321).withValues(alpha: .4),
                      const Color(0xFFFFB321).withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArcadeText(p.text,
                      size: _cell * (p.text.length > 10 ? .85 : 1.08)),
                  if (p.sub != null)
                    ArcadeText(p.sub!,
                        size: _cell * .52,
                        colors: const [Color(0xFFB8F7FF), Color(0xFF3FC3F2)],
                        stroke: const Color(0xFF0B2350)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tray(AppTheme t, BlockSkin skin, double width, double height) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: SizedBox(
                key: _slotKeys[i],
                height: height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft spotlight pad the piece rests on.
                    Container(
                      width: width / 3 - 14,
                      height: height * .88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: RadialGradient(
                          radius: .75,
                          colors: [
                            Colors.white.withValues(alpha: .11),
                            Colors.white.withValues(alpha: .02),
                          ],
                        ),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .07)),
                      ),
                    ),
                    Positioned.fill(child: _slot(i, skin)),
                  ],
                ),
              ),
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
          duration: Duration(milliseconds: 420 + i * 90),
          curve: Interval(i * .18, 1, curve: Curves.easeOutBack),
          builder: (_, k, child) => Transform.translate(
            offset: Offset((1 - k) * 60, 0),
            child: Transform.scale(scale: k, child: child),
          ),
          child: ColorFiltered(
            colorFilter: fits
                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                : const ColorFilter.matrix(<double>[
                    .33, .33, .33, 0, 0, //
                    .33, .33, .33, 0, 0, //
                    .33, .33, .33, 0, 0, //
                    0, 0, 0, .45, 0,
                  ]),
            child: CustomPaint(
              size: Size(s.width * _trayCell, s.height * _trayCell),
              painter: PiecePainter(
                shape: s,
                color: skin.forPiece(s.color),
                cell: _trayCell,
              ),
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
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      builder: (_, k, __) {
        final cell = lerpDouble(_trayCell, _cell, k)!;
        final tl = _pieceTopLeft(s, k.clamp(0, 1), cell);
        return Positioned(
          left: tl.dx,
          top: tl.dy,
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(s.width * cell, s.height * cell),
              painter: PiecePainter(
                shape: s,
                color: skin.forPiece(s.color),
                cell: cell,
                lifted: k.clamp(0, 1),
              ),
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
      duration: const Duration(milliseconds: 200),
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
                  shape: s,
                  color: skin.forPiece(s.color),
                  cell: cell,
                  lifted: 1 - k),
            ),
          ),
        );
      },
    );
  }

  Widget _results(AppTheme t) {
    final o = _outcome;
    final newBest = o?.isNewBest ?? false;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (_, k, child) => ColoredBox(
          color: Colors.black.withValues(alpha: .7 * k),
          child: Opacity(
            opacity: k,
            child: Transform.scale(
              scale: .85 + .15 * Curves.easeOutBack.transform(k),
              child: child,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 20,
              child: LightRays(
                size: 520,
                color: newBest ? const Color(0xFFFFD66B) : const Color(0xFF8FA2FF),
              ),
            ),
            if (newBest) const Positioned.fill(child: Confetti()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (newBest) ...[
                    const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD34D), size: 64,
                        shadows: [Shadow(color: Color(0xAAFFB321), blurRadius: 24)]),
                    const ArcadeText('New Best!', size: 46),
                  ] else
                    const ArcadeText('Game Over',
                        size: 40,
                        colors: [Colors.white, Color(0xFFCFD6FF)],
                        stroke: Color(0xFF14154A)),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(t.surface, Colors.white, .14)!,
                          t.surface,
                        ],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: .18), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .4),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text('SCORE',
                            style: TextStyle(
                                fontFamily: kFont,
                                color: t.subtext,
                                fontSize: 15,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w800)),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _session.score.toDouble()),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => ArcadeText('${v.round()}',
                              size: 68,
                              colors: const [Colors.white, Color(0xFFD9DEFF)],
                              stroke: t.boardFrame),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                icon: const Icon(Icons.emoji_events_rounded,
                                    color: Color(0xFFFFC93C), size: 24),
                                label: 'BEST',
                                value: '$_best',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatChip(
                                icon: const CoinIcon(size: 22),
                                label: 'COINS',
                                value: '+${o?.coinsEarned ?? 0}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Pulse(
                    child: ChunkyButton(
                      color: t.accent,
                      width: 260,
                      height: 60,
                      onPressed: _restart,
                      child: const _ButtonLabel(Icons.replay_rounded, 'Play Again'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ChunkyButton(
                    color: const Color(0xFF5865F2),
                    width: 260,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const _ButtonLabel(Icons.home_rounded, 'Home'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPause(AppTheme t) {
    Sound.instance.play(SoundEffect.tap);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(t.surface, Colors.white, .14)!, t.surface],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .18), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .5),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: AppState.instance,
            builder: (ctx, _) {
              final app = AppState.instance;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ArcadeText('Paused', size: 38),
                  const SizedBox(height: 18),
                  _ToggleRow(
                    icon: Icons.music_note_rounded,
                    label: 'Music',
                    value: app.musicOn,
                    theme: t,
                    onChanged: app.setMusicOn,
                  ),
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

class _BestBadge extends StatelessWidget {
  const _BestBadge({required this.best, required this.theme});
  final int best;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-.3, -.4),
                  colors: [Color(0xFFFFF1A8), Color(0xFFFFB21E), Color(0xFFC77A0C)],
                ),
                boxShadow: [BoxShadow(color: Color(0x88FFB321), blurRadius: 12)],
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFF8A4E00), size: 20),
            ),
            const SizedBox(width: 8),
            Text('$best',
                style: const TextStyle(
                    fontFamily: kFont,
                    color: Color(0xFFFFD45C),
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _DailyTag extends StatelessWidget {
  const _DailyTag();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFB37BFF), Color(0xFF7B3FE4)]),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .25)),
        ),
        child: const Text('DAILY',
            style: TextStyle(
                fontFamily: kFont,
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800)),
      );
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({super.key, required this.combo});
  final int combo;

  @override
  Widget build(BuildContext context) => Pulse(
        amount: .07,
        period: 600,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
                colors: [Color(0xFFFFB02E), Color(0xFFFF4D3A)]),
            border: Border.all(color: Colors.white.withValues(alpha: .35)),
            boxShadow: const [BoxShadow(color: Color(0x88FF6A2E), blurRadius: 14)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 4),
              Text('COMBO x$combo',
                  style: const TextStyle(
                      fontFamily: kFont,
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value});
  final Widget icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontFamily: kFont,
                          color: Color(0xFFB7BBF0),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800)),
                  Text(value,
                      style: const TextStyle(
                          fontFamily: kFont,
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.1,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26,
              shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 1.5))]),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: kFont,
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 1.5))])),
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
        width: 48,
        height: 44,
        radius: 15,
        onPressed: onTap,
        child: Icon(icon, color: Colors.white, size: 28),
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

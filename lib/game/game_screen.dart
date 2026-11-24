import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/ads.dart';
import '../app/app_state.dart';
import '../app/music.dart';
import '../app/sound.dart';
import '../app/theme.dart';
import '../ui/fx.dart';
import '../ui/widgets.dart';
import 'board_painter.dart';
import 'engine.dart';
import 'modes.dart';
import 'powerups.dart';
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

  // Power-ups.
  PowerUp? _armed; // Bomb/Rotate waiting for the player's tap
  SessionSnapshot? _undo;
  final Map<int, int> _spinGen = {};

  // Revive.
  int _revivesUsed = 0;
  bool _offerRevive = false;
  bool _reviveBusy = false;
  int _reviveGen = 0;

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

  @visibleForTesting
  GameSession get session => _session;

  @visibleForTesting
  void triggerGameOver() => _startGameOver();

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
      _armed = null;
      _undo = null;
      _revivesUsed = 0;
      _offerRevive = false;
      _reviveBusy = false;
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
    if (_armed == PowerUp.rotate) {
      _applyRotate(i);
      return;
    }
    if (_armed != null) _disarm();
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
    final snap = _session.snapshot();
    final result = _session.place(i, at.x, at.y);
    if (result == null) return;
    _undo = snap;

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
          _flashStrength =
              result.allClear ? .55 : .12 + .06 * result.linesCleared;
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
    const words = [
      'Good!',
      'Great!',
      'Excellent!',
      'Amazing!',
      'Unbelievable!'
    ];
    if (level < 2) return sub == null ? null : _Popup(sub, null, _gen);
    return _Popup(words[math.min(level - 2, words.length - 1)], sub, _gen);
  }

  void _startGameOver() {
    if (_over || !mounted) return;
    Sound.instance.play(SoundEffect.gameOver);
    Music.instance.duck(true);
    if (AppState.instance.hapticsOn) HapticFeedback.heavyImpact();
    setState(() {
      _over = true;
      _armed = null;
      _overGen++;
    });
    final gen = _overGen;
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted || !_over || _overGen != gen) return;
      if (_canContinue) {
        setState(() {
          _offerRevive = true;
          _reviveGen++;
        });
      } else {
        _finishGame();
      }
    });
  }

  bool get _powerUpsAllowed => widget.mode == GameMode.classic;

  bool get _canRevive => _powerUpsAllowed && _revivesUsed < ReviveRules.perGame;

  /// Owned power-ups that can rescue a stuck board.
  List<PowerUp> get _rescuePowerUps => !_powerUpsAllowed
      ? const []
      : [
          for (final p in const [PowerUp.bomb, PowerUp.shuffle])
            if (AppState.instance.powerUpCount(p) > 0) p,
        ];

  bool get _canContinue => _canRevive || _rescuePowerUps.isNotEmpty;

  /// The game is really over: record it and show the results.
  void _finishGame() {
    if (!mounted || _showResults) return;
    final outcome = AppState.instance.recordGameResult(
      mode: _session.mode,
      score: _session.score,
      linesCleared: _session.linesClearedTotal,
      movesPlayed: _session.movesPlayed,
      day: _day,
    );
    setState(() {
      _offerRevive = false;
      _outcome = outcome;
      _showResults = true;
    });
    if (outcome.isNewBest) Sound.instance.play(SoundEffect.coin);
  }

  void _declineRevive() {
    if (!_offerRevive || _reviveBusy) return;
    _finishGame();
  }

  /// Leaves the game-over state and plays again from the current board.
  void _resume() {
    Music.instance.duck(false);
    _over = false;
    _offerRevive = false;
    _overGen++;
  }

  Future<void> _revive({required bool viaAd}) async {
    if (_reviveBusy) return;
    final app = AppState.instance;
    if (viaAd) {
      setState(() => _reviveBusy = true);
      final earned = await Ads.instance.showRewarded();
      if (!mounted) return;
      setState(() => _reviveBusy = false);
      if (!earned) return; // stay on the offer; they can still decide
    } else if (!app.spendCoins(ReviveRules.coinPrice)) {
      return;
    }
    final cleared = _session.revive();
    _revivesUsed++;
    final mid = Offset(
        _cell * _session.board.size / 2, _cell * _session.board.size / 2);
    setState(() {
      _resume();
      _undo = null;
      _gen++;
      _trayGen++;
      _clearFx = buildBurstFx(
        cleared: cleared,
        strength: 3,
        boardSize: _session.board.size,
        cell: _cell,
        from: mid,
        skin: app.skin,
        rng: _rng,
      );
      _praise = _Popup('Revived!', 'Keep going', _gen);
      _flashGen++;
      _flashStrength = .45;
      _shakeGen++;
      _shakeAmp = _cell * .18;
    });
    Sound.instance.play(SoundEffect.combo);
    if (app.hapticsOn) HapticFeedback.heavyImpact();
  }

  /// From the stuck-board offer: use an owned Bomb or Shuffle instead.
  void _rescueWith(PowerUp p) {
    setState(_resume);
    _onPowerUp(p);
  }

  // -------------------------------------------------------------- power-ups

  void _onPowerUp(PowerUp p) {
    if (!_powerUpsAllowed || _over || _dragIndex != null) return;
    if (_armed == p) {
      _disarm();
      return;
    }
    final app = AppState.instance;
    if (p == PowerUp.undo && _undo == null) {
      _toast('Nothing to undo yet');
      return;
    }
    if (app.powerUpCount(p) <= 0) {
      _offerPowerUp(p);
      return;
    }
    Sound.instance.play(SoundEffect.tap);
    switch (p) {
      case PowerUp.undo:
        app.usePowerUp(p);
        setState(() {
          _session.restore(_undo!);
          _undo = null;
          _clearFx = null;
          _praise = null;
          _scorePop = null;
          _popCells = const {};
          _gen++;
        });
      case PowerUp.shuffle:
        app.usePowerUp(p);
        setState(() {
          _session.shuffle();
          _undo = null;
          _trayGen++;
        });
      case PowerUp.bomb:
      case PowerUp.rotate:
        setState(() => _armed = p);
    }
    _checkStuckAfterPowerUp();
  }

  void _applyRotate(int i) {
    final app = AppState.instance;
    if (!app.usePowerUp(PowerUp.rotate)) return;
    Sound.instance.play(SoundEffect.pick);
    if (app.hapticsOn) HapticFeedback.selectionClick();
    setState(() {
      _session.rotate(i);
      _spinGen[i] = (_spinGen[i] ?? 0) + 1;
      _armed = null;
    });
    _checkStuckAfterPowerUp();
  }

  void _bombAt(Offset local) {
    final x = (local.dx / _cell).floor(), y = (local.dy / _cell).floor();
    if (!_session.board.inBounds(x, y)) return;
    final app = AppState.instance;
    var any = false;
    for (var yy = y - 1; yy <= y + 1; yy++) {
      for (var xx = x - 1; xx <= x + 1; xx++) {
        if (_session.board.inBounds(xx, yy) &&
            !_session.board.isEmptyAt(xx, yy)) {
          any = true;
        }
      }
    }
    if (!any) {
      _toast('Aim at some blocks!');
      return;
    }
    if (!app.usePowerUp(PowerUp.bomb)) return;
    final cleared = _session.bomb(x, y);
    setState(() {
      _armed = null;
      _undo = null;
      _gen++;
      _clearFx = buildBurstFx(
        cleared: cleared,
        strength: 2,
        boardSize: _session.board.size,
        cell: _cell,
        from: Offset((x + .5) * _cell, (y + .5) * _cell),
        skin: app.skin,
        rng: _rng,
      );
      _praise = _Popup('Boom!', null, _gen);
      _flashGen++;
      _flashStrength = .3;
      _shakeGen++;
      _shakeAmp = _cell * .2;
    });
    Sound.instance.play(SoundEffect.combo);
    if (app.hapticsOn) HapticFeedback.heavyImpact();
    _checkStuckAfterPowerUp();
  }

  /// Cancels an armed Bomb/Rotate.
  void _disarm() {
    setState(() => _armed = null);
    _checkStuckAfterPowerUp();
  }

  /// After a power-up (or cancelling one) the board may have no moves left;
  /// end the game then — but never while a Bomb/Rotate is still being aimed.
  void _checkStuckAfterPowerUp() {
    if (!_session.gameOver || _over || _armed != null) return;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _session.gameOver && !_over && _armed == null) {
        _startGameOver();
      }
    });
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: kFont, fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
        backgroundColor: Colors.black.withValues(alpha: .8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
  }

  void _offerPowerUp(PowerUp p) {
    final t = AppState.instance.theme;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ListenableBuilder(
          listenable: Listenable.merge([AppState.instance, Ads.instance]),
          builder: (ctx, _) {
            final app = AppState.instance;
            final adReady = Ads.instance.ready;
            return _Panel(
              theme: t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PowerIcon(p: p, size: 76),
                  const SizedBox(height: 12),
                  ArcadeText('Need a ${p.label}?', size: 30),
                  const SizedBox(height: 6),
                  Text(p.hint,
                      textAlign: TextAlign.center,
                      style: t.body(15, color: t.subtext)),
                  const SizedBox(height: 20),
                  ChunkyButton(
                    color: const Color(0xFF9B5BF5),
                    onPressed: adReady
                        ? () async {
                            final earned = await Ads.instance.showRewarded();
                            if (earned) {
                              app.addPowerUp(p);
                              Sound.instance.play(SoundEffect.coin);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            }
                          }
                        : null,
                    child: _ButtonLabel(Icons.smart_display_rounded,
                        adReady ? 'Watch ad  +1' : 'No ad right now'),
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton(
                    color: const Color(0xFFFFA41C),
                    onPressed: app.coins >= p.price
                        ? () {
                            app.buyPowerUp(p);
                            Sound.instance.play(SoundEffect.coin);
                            Navigator.of(ctx).pop();
                          }
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CoinIcon(size: 26),
                        const SizedBox(width: 8),
                        Text('${p.price}  +1',
                            style: const TextStyle(
                                fontFamily: kFont,
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('You have ${app.coins} coins',
                      style: t.body(13, color: t.subtext)),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Not now',
                        style: t.body(15,
                            color: t.subtext, weight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
                      const barH = 72.0;
                      final byHeight =
                          (c.maxHeight - 40 - barH) / (1 + trayCells * .94 / n);
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
                          Expanded(
                              flex: 3, child: Center(child: _armedHint(t))),
                          _tray(t, skin, c.maxWidth, _cell * trayCells),
                          const SizedBox(height: 6),
                          SizedBox(height: barH, child: _powerBar(t)),
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
              if (_offerRevive) _reviveOffer(t),
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
                            key: ValueKey(_session.combo),
                            combo: _session.combo)
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

  Widget _board(
      AppTheme t, BlockSkin skin, double outer, double pad, double grid) {
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp:
                _armed == PowerUp.bomb ? (d) => _bombAt(d.localPosition) : null,
            child: SizedBox(
              key: _gridKey,
              width: grid,
              height: grid,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_armed == PowerUp.bomb)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Pulse(
                          amount: .015,
                          period: 500,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_cell * .2),
                              border: Border.all(
                                  color: const Color(0xFFFF5A4E), width: 3),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x88FF5A4E), blurRadius: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => TweenAnimationBuilder<double>(
                          key: ValueKey('pop$_gen'),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 260),
                          builder: (_, popT, __) =>
                              TweenAnimationBuilder<double>(
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
                            painter: ClearFxPainter(
                                fx: _clearFx!, cell: _cell, t: k),
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
                            curve: const Interval(.4, 1,
                                curve: Curves.easeOutBack),
                            builder: (_, k, child) => Opacity(
                              opacity: k.clamp(0, 1),
                              child: Transform.scale(
                                  scale: .6 + .4 * k, child: child),
                            ),
                            child: ArcadeText('No More Space',
                                size: _cell * .8,
                                colors: const [
                                  Color(0xFFFFB3B3),
                                  Color(0xFFFF4D5E)
                                ],
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
              : ColoredBox(
                  color: Colors.white.withValues(alpha: _flashStrength * k)),
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
                  scale: .7 +
                      .3 * Curves.easeOutBack.transform((k / .3).clamp(0, 1)),
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
          child: TweenAnimationBuilder<double>(
            key: ValueKey('spin$i-${_spinGen[i] ?? 0}'),
            tween: Tween(begin: (_spinGen[i] ?? 0) == 0 ? 0 : -1, end: 0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (_, k, child) => Transform.rotate(
              angle: k * math.pi / 2,
              child: _armed == PowerUp.rotate
                  ? Pulse(amount: .08, period: 450, child: child!)
                  : child,
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

  Widget _armedHint(AppTheme t) {
    final p = _armed;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: p == null
          ? const SizedBox.shrink()
          : GestureDetector(
              key: ValueKey(p),
              onTap: _disarm,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                decoration: BoxDecoration(
                  color: p.color.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .35)),
                  boxShadow: [
                    BoxShadow(
                        color: p.color.withValues(alpha: .5), blurRadius: 14)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                          p == PowerUp.bomb
                              ? 'Tap the board to blast'
                              : 'Tap a piece to rotate',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: kFont,
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _powerBar(AppTheme t) {
    if (!_powerUpsAllowed) {
      return Center(
        child: Text('Daily Challenge: same board for everyone, no power-ups',
            textAlign: TextAlign.center,
            style: t.body(13, color: t.subtext, weight: FontWeight.w700)),
      );
    }
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final p in PowerUp.values)
            _PowerButton(
              p: p,
              count: AppState.instance.powerUpCount(p),
              armed: _armed == p,
              enabled: !_over && (p != PowerUp.undo || _undo != null),
              onTap: () => _onPowerUp(p),
            ),
        ],
      ),
    );
  }

  Widget _reviveOffer(AppTheme t) {
    final app = AppState.instance;
    final rescues = _rescuePowerUps;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .62),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (_, k, child) =>
                  Transform.scale(scale: .7 + .3 * k, child: child),
              child: _Panel(
                theme: t,
                child: ListenableBuilder(
                  listenable: Listenable.merge([app, Ads.instance]),
                  builder: (_, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ArcadeText('Out of Space!',
                          size: 34,
                          colors: [Color(0xFFFFB3B3), Color(0xFFFF4D5E)],
                          stroke: Color(0xFF3D0610)),
                      const SizedBox(height: 4),
                      Text('Score ${_session.score}  ·  keep going?',
                          style: t.body(15,
                              color: t.subtext, weight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      // Countdown ring.
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('revive$_reviveGen'),
                          tween: Tween(begin: 1, end: 0),
                          duration:
                              const Duration(seconds: ReviveRules.offerSeconds),
                          onEnd: _declineRevive,
                          builder: (_, v, __) => Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: v,
                                  strokeWidth: 7,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: .12),
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFFFFC93C)),
                                ),
                              ),
                              Text('${(v * ReviveRules.offerSeconds).ceil()}',
                                  style: const TextStyle(
                                      fontFamily: kFont,
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_canRevive) ...[
                        Pulse(
                          child: ChunkyButton(
                            color: t.accent,
                            height: 58,
                            onPressed: Ads.instance.ready && !_reviveBusy
                                ? () => _revive(viaAd: true)
                                : null,
                            child: _ButtonLabel(
                                Icons.smart_display_rounded,
                                Ads.instance.ready
                                    ? 'Revive  ·  Watch ad'
                                    : 'Ad loading…'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ChunkyButton(
                          color: const Color(0xFFFFA41C),
                          onPressed:
                              app.coins >= ReviveRules.coinPrice && !_reviveBusy
                                  ? () => _revive(viaAd: false)
                                  : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Revive  ·  ',
                                  style: TextStyle(
                                      fontFamily: kFont,
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const CoinIcon(size: 24),
                              const SizedBox(width: 6),
                              Text('${ReviveRules.coinPrice}',
                                  style: const TextStyle(
                                      fontFamily: kFont,
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                      if (rescues.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('or use a power-up',
                            style: t.body(13,
                                color: t.subtext, weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final p in rescues)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: _PowerButton(
                                  p: p,
                                  count: app.powerUpCount(p),
                                  armed: false,
                                  enabled: !_reviveBusy,
                                  onTap: () => _rescueWith(p),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _reviveBusy ? null : _finishGame,
                        child: Text('No thanks',
                            style: t.body(15,
                                color: t.subtext, weight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
                color:
                    newBest ? const Color(0xFFFFD66B) : const Color(0xFF8FA2FF),
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
                        color: Color(0xFFFFD34D),
                        size: 64,
                        shadows: [
                          Shadow(color: Color(0xAAFFB321), blurRadius: 24)
                        ]),
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
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                          width: 1.5),
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
                          tween:
                              Tween(begin: 0, end: _session.score.toDouble()),
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
                      onPressed: () async {
                        await Ads.instance.afterGame();
                        if (mounted) _restart();
                      },
                      child: const _ButtonLabel(
                          Icons.replay_rounded, 'Play Again'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ChunkyButton(
                    color: const Color(0xFF5865F2),
                    width: 260,
                    onPressed: () async {
                      await Ads.instance.afterGame();
                      if (mounted) Navigator.of(context).maybePop();
                    },
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
            border: Border.all(
                color: Colors.white.withValues(alpha: .18), width: 1.5),
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
                    child:
                        const _ButtonLabel(Icons.play_arrow_rounded, 'Resume'),
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

class _Panel extends StatelessWidget {
  const _Panel({required this.theme, required this.child});
  final AppTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(theme.surface, Colors.white, .14)!,
              theme.surface
            ],
          ),
          border: Border.all(
              color: Colors.white.withValues(alpha: .18), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .5),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: child,
      );
}

class _PowerIcon extends StatelessWidget {
  const _PowerIcon({required this.p, this.size = 54});
  final PowerUp p;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-.3, -.45),
            colors: [
              Color.lerp(p.color, Colors.white, .45)!,
              p.color,
              Color.lerp(p.color, Colors.black, .35)!,
            ],
            stops: const [0, .55, 1],
          ),
          border:
              Border.all(color: Colors.white.withValues(alpha: .5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child:
            Icon(p.icon, color: Colors.white, size: size * .52, shadows: const [
          Shadow(
              color: Color(0x66000000), offset: Offset(0, 1.5), blurRadius: 2),
        ]),
      );
}

/// A round power-up button with its count badge (or price when empty).
class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.p,
    required this.count,
    required this.armed,
    required this.enabled,
    required this.onTap,
  });

  final PowerUp p;
  final int count;
  final bool armed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget icon = _PowerIcon(p: p);
    if (armed) {
      icon = Pulse(
        amount: .1,
        period: 450,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: p.color, blurRadius: 18, spreadRadius: 3),
              const BoxShadow(
                  color: Colors.white, blurRadius: 0, spreadRadius: 2.5),
            ],
          ),
          child: icon,
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: SizedBox(
          width: 66,
          height: 66,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              icon,
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: count > 0
                        ? const Color(0xFFF23F5B)
                        : const Color(0xFF2A2C7A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: count > 0
                        ? Text('$count',
                            style: const TextStyle(
                                fontFamily: kFont,
                                color: Colors.white,
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w800))
                        : const Icon(Icons.add_rounded,
                            color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
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
                  colors: [
                    Color(0xFFFFF1A8),
                    Color(0xFFFFB21E),
                    Color(0xFFC77A0C)
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x88FFB321), blurRadius: 12)
                ],
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
            boxShadow: const [
              BoxShadow(color: Color(0x88FF6A2E), blurRadius: 14)
            ],
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
  const _StatChip(
      {required this.icon, required this.label, required this.value});
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
          Icon(icon, color: Colors.white, size: 26, shadows: const [
            Shadow(color: Color(0x55000000), offset: Offset(0, 1.5))
          ]),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: kFont,
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(color: Color(0x55000000), offset: Offset(0, 1.5))
                  ])),
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

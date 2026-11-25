import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/sound.dart';
import '../app/theme.dart';
import '../game/game_screen.dart';
import '../game/levels.dart';
import '../game/modes.dart';
import 'fx.dart';
import 'widgets.dart';
import '../l10n/l10n.dart';

/// The Adventure map: a winding trail of level bubbles, level 1 at the
/// bottom, opening scrolled to the player's current level.
class AdventureScreen extends StatefulWidget {
  const AdventureScreen({super.key});

  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends State<AdventureScreen> {
  static const _rowH = 118.0;
  static const _node = 78.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _focusCurrent() {
    if (!_scroll.hasClients) return;
    final current = AppState.instance.unlockedLevel;
    final view = _scroll.position.viewportDimension;
    final target = (current - 1) * _rowH - view / 2 + _rowH;
    _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
  }

  /// Horizontal position (0..1) of a level's bubble along the trail.
  static double _x(int level) => .5 + .3 * math.sin(level * .95);

  void _open(Level level) {
    Sound.instance.play(SoundEffect.tap);
    final t = AppState.instance.theme;
    final best = AppState.instance.levelStars[level.number] ?? 0;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(t.surface, Colors.white, .14)!, t.surface],
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: .18), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArcadeText(tr('Level {n}', {'n': level.number}), size: 40),
              const SizedBox(height: 8),
              _Stars(stars: best, size: 34),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(_goalIcon(level.goal),
                        color: const Color(0xFF7FE3FF), size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('GOAL'),
                              style: t.body(11,
                                  color: t.subtext, weight: FontWeight.w800)),
                          Text(level.goal.describe(level.target),
                              style: t.title(19, color: Colors.white)),
                          Text(tr('3 stars in {n} moves or fewer', {'n': level.par}),
                              style: t.body(12, color: t.subtext)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Pulse(
                child: PrimaryButton(
                  label: tr('PLAY'),
                  theme: t,
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                          builder: (_) => GameScreen(
                              mode: GameMode.adventure, level: level),
                        ))
                        .then((_) => setState(() {}));
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('Close'),
                    style:
                        t.body(15, color: t.subtext, weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _goalIcon(LevelGoal g) => switch (g) {
        LevelGoal.score => Icons.star_rounded,
        LevelGoal.lines => Icons.view_stream_rounded,
        LevelGoal.gems => Icons.diamond_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final app = AppState.instance;
        final t = app.theme;
        final unlocked = app.unlockedLevel;
        return Scaffold(
          backgroundColor: t.background,
          body: AmbientBackground(
            theme: t,
            child: SafeArea(
              child: MaxWidth(
                width: 620,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
                      child: Row(
                        children: [
                          ChunkyButton(
                            color: Color.lerp(t.surface, Colors.white, .12)!,
                            width: 48,
                            height: 44,
                            radius: 15,
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: ScreenTitle(tr('Adventure'))),
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .12)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFFFCC33), size: 26),
                                const SizedBox(width: 4),
                                Text('${app.totalStars}/${Levels.count * 3}',
                                    style: const TextStyle(
                                        fontFamily: kFont,
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth;
                          final h = Levels.count * _rowH + 60;
                          Offset pos(int n) =>
                              Offset(w * _x(n), h - 40 - (n - .5) * _rowH);
                          return SingleChildScrollView(
                            controller: _scroll,
                            reverse: true,
                            child: SizedBox(
                              width: w,
                              height: h,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _TrailPainter(
                                        points: [
                                          for (var n = 1;
                                              n <= Levels.count;
                                              n++)
                                            pos(n)
                                        ],
                                        reached: unlocked,
                                      ),
                                    ),
                                  ),
                                  for (var n = 1; n <= Levels.count; n++)
                                    Positioned(
                                      left: pos(n).dx - _node / 2,
                                      top: pos(n).dy - _node / 2,
                                      child: _LevelNode(
                                        number: n,
                                        stars: app.levelStars[n],
                                        current: n == unlocked &&
                                            !app.levelStars.containsKey(n),
                                        locked: n > unlocked,
                                        size: _node,
                                        onTap: n > unlocked
                                            ? null
                                            : () => _open(Levels.get(n)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.points, required this.reached});
  final List<Offset> points;
  final int reached;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final done = i + 2 <= reached;
      final dots = 7;
      for (var k = 1; k < dots; k++) {
        final p = Offset.lerp(a, b, k / dots)! +
            Offset(math.sin(k / dots * math.pi) * 18 * (i.isEven ? 1 : -1), 0);
        canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = done
                ? const Color(0xFFFFD45C)
                : Colors.white.withValues(alpha: .22),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => old.reached != reached;
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.number,
    required this.stars,
    required this.current,
    required this.locked,
    required this.size,
    required this.onTap,
  });

  final int number;
  final int? stars;
  final bool current;
  final bool locked;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cleared = stars != null;
    final colors = locked
        ? const [Color(0xFF8A8FB0), Color(0xFF555A7A)]
        : cleared
            ? const [Color(0xFFFFE27A), Color(0xFFFFA51C)]
            : const [Color(0xFF7DF0A0), Color(0xFF22B45A)];
    Widget node = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .7), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          if (current)
            const BoxShadow(
                color: Color(0xAA3FD16B), blurRadius: 24, spreadRadius: 4),
        ],
      ),
      child: Center(
        child: locked
            ? const Icon(Icons.lock_rounded, color: Colors.white70, size: 30)
            : ArcadeText('$number',
                size: 30,
                colors: const [Colors.white, Color(0xFFF2F2F2)],
                stroke: cleared
                    ? const Color(0xFF8A4E00)
                    : const Color(0xFF0B5A2A)),
      ),
    );
    if (current) node = Pulse(amount: .08, period: 800, child: node);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size + 18,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            node,
            if (cleared)
              Positioned(
                bottom: -6,
                child: _Stars(stars: stars!, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.stars, required this.size});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(Icons.star_rounded,
                size: size,
                color: i < stars
                    ? const Color(0xFFFFCC33)
                    : Colors.white.withValues(alpha: .25),
                shadows: const [
                  Shadow(color: Color(0x66000000), blurRadius: 4)
                ]),
        ],
      );
}

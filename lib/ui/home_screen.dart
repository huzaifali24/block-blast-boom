import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import '../game/board_painter.dart';
import '../game/game_screen.dart';
import '../game/modes.dart';
import 'adventure_screen.dart';
import 'fx.dart';
import 'rewards_ui.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _play(BuildContext context, Widget screen) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 1.08, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final today = DateTime.now();

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final t = app.theme;
        // No scrolling: the logo block scales down to whatever height is
        // left, so Play and Daily are always on screen on any phone.
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
          child: Column(
            children: [
              Row(
                children: [
                  if (app.dailyStreak > 0) _StreakChip(streak: app.dailyStreak),
                  const Spacer(),
                  _BadgeButton(
                    icon: Icons.card_giftcard_rounded,
                    color: const Color(0xFFF23F5B),
                    dot: app.loginRewardReady,
                    onTap: () => showLoginCalendar(context),
                  ),
                  const SizedBox(width: 10),
                  _BadgeButton(
                    icon: Icons.casino_rounded,
                    color: const Color(0xFF9B5BF5),
                    dot: app.freeSpinReady,
                    onTap: () => showLuckyWheel(context),
                  ),
                  const SizedBox(width: 10),
                  CoinPill(coins: app.coins, theme: t),
                ],
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Bob(
                      distance: 8,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const LightRays(size: 300, color: Color(0xFF9FB0FF)),
                              _LogoBlocks(colors: app.skin.colors),
                            ],
                          ),
                          Transform.translate(
                            offset: const Offset(0, -46),
                            child: const Column(
                              children: [
                                ArcadeText('BLOCK', size: 58),
                                ArcadeText('BOOM',
                                    size: 72,
                                    colors: [Color(0xFFFFB0C0), Color(0xFFF23F5B)],
                                    stroke: Color(0xFF3D0614)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _BestPlaque(best: app.bestClassic, theme: t),
              const SizedBox(height: 18),
              Pulse(
                child: PrimaryButton(
                  label: 'PLAY',
                  theme: t,
                  icon: Icons.play_arrow_rounded,
                  onPressed: () =>
                      _play(context, const GameScreen(mode: GameMode.classic)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'LEVEL ${app.unlockedLevel}',
                      theme: t,
                      color: const Color(0xFFFF8A1C),
                      icon: Icons.map_rounded,
                      onPressed: () =>
                          _play(context, const AdventureScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: app.dailyDoneToday
                          ? 'BEST ${app.bestDailyFor(today)}'
                          : 'DAILY',
                      theme: t,
                      color: const Color(0xFF9B5BF5),
                      icon: Icons.calendar_month_rounded,
                      onPressed: () => _play(
                          context, GameScreen(mode: GameMode.daily, day: today)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Round icon button with an optional red "something's waiting" dot.
class _BadgeButton extends StatelessWidget {
  const _BadgeButton({
    required this.icon,
    required this.color,
    required this.dot,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget b = ChunkyButton(
      color: color,
      width: 46,
      height: 42,
      radius: 14,
      onPressed: onTap,
      child: Icon(icon, color: Colors.white, size: 26),
    );
    if (dot) b = Pulse(amount: .06, period: 700, child: b);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        b,
        if (dot)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _BestPlaque extends StatelessWidget {
  const _BestPlaque({required this.best, required this.theme});
  final int best;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 22, 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFFC93C).withValues(alpha: .4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-.3, -.4),
                  colors: [Color(0xFFFFF1A8), Color(0xFFFFB21E), Color(0xFFC77A0C)],
                ),
                boxShadow: [BoxShadow(color: Color(0x88FFB321), blurRadius: 14)],
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFF8A4E00), size: 24),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BEST SCORE',
                    style: TextStyle(
                        fontFamily: kFont,
                        color: theme.subtext,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800)),
                Text('$best',
                    style: const TextStyle(
                        fontFamily: kFont,
                        color: Color(0xFFFFD45C),
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      );
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
              colors: [Color(0xFFFFB02E), Color(0xFFFF4D3A)]),
          border: Border.all(color: Colors.white.withValues(alpha: .3)),
          boxShadow: const [BoxShadow(color: Color(0x66FF6A2E), blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 4),
            Text('$streak',
                style: const TextStyle(
                    fontFamily: kFont,
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

/// The title art: a little tumbling stack of glossy blocks.
class _LogoBlocks extends StatelessWidget {
  const _LogoBlocks({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(220, 150),
        painter: _LogoPainter(colors),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.colors);
  final List<Color> colors;

  // (x, y, color index, tilt) on a loose 4x3 grid.
  static const _cells = [
    (0.0, 2.0, 3, -.08), (1.0, 2.0, 3, 0.0), (1.0, 1.0, 3, 0.0),
    (2.0, 2.0, 0, 0.0), (2.0, 1.0, 1, .05), (3.0, 2.0, 2, .04),
    (3.0, 1.0, 6, 0.0), (2.6, -.1, 5, .35), (.2, .9, 4, -.3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height / 3.1;
    final ox = (size.width - cell * 4) / 2;
    for (final (x, y, c, tilt) in _cells) {
      final r = Rect.fromLTWH(ox + x * cell, y * cell + cell * .1, cell, cell);
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(tilt * math.pi / 2);
      paintBlock(canvas, Rect.fromCenter(center: Offset.zero, width: cell, height: cell),
          colors[c % colors.length]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.colors != colors;
}

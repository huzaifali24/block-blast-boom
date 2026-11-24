import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import '../game/board_painter.dart';
import '../game/game_screen.dart';
import '../game/modes.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final today = DateTime.now();

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final t = app.theme;
        return LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: CoinPill(coins: app.coins, theme: t),
                    ),
                    const SizedBox(height: 24),
                    const _LogoBlocks(),
                    const SizedBox(height: 18),
                    const ArcadeText('BLOCK', size: 54),
                    const ArcadeText('BOOM',
                        size: 64,
                        colors: [Color(0xFFFFB0C0), Color(0xFFF23F5B)],
                        stroke: Color(0xFF3D0614)),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_rounded, color: t.gold, size: 28),
                        const SizedBox(width: 8),
                        Text('${app.bestClassic}',
                            style: TextStyle(
                                fontFamily: kFont,
                                color: t.gold,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 36),
                    PrimaryButton(
                      label: 'PLAY',
                      theme: t,
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const GameScreen(mode: GameMode.classic),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: app.dailyDoneToday
                          ? 'DAILY  ·  BEST ${app.bestDailyFor(today)}'
                          : 'DAILY CHALLENGE',
                      theme: t,
                      color: const Color(0xFF9B5BF5),
                      icon: Icons.calendar_today_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GameScreen(mode: GameMode.daily, day: today),
                        ),
                      ),
                    ),
                    if (app.dailyStreak > 0) ...[
                      const SizedBox(height: 12),
                      Text('🔥 ${app.dailyStreak}-day streak',
                          style: t.body(15,
                              color: t.gold, weight: FontWeight.w700)),
                    ],
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

/// A little cluster of blocks used as the title art.
class _LogoBlocks extends StatelessWidget {
  const _LogoBlocks();

  @override
  Widget build(BuildContext context) {
    final skin = AppState.instance.skin;
    return CustomPaint(
      size: const Size(176, 88),
      painter: _LogoPainter(skin.colors),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.colors);
  final List<Color> colors;

  // (x, y, color index) on a 4x2 grid.
  static const _cells = [
    (0, 1, 3), (1, 1, 3), (1, 0, 3),
    (2, 0, 1), (2, 1, 0), (3, 1, 2), (3, 0, 6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height / 2;
    for (final (x, y, c) in _cells) {
      paintBlock(canvas, Rect.fromLTWH(x * cell, y * cell, cell, cell),
          colors[c % colors.length]);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.colors != colors;
}

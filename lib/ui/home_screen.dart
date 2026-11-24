import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../game/game_screen.dart';
import '../game/modes.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final t = app.theme;
    final today = DateTime.now();

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Block Bloom',
                    style: t.title(26, weight: FontWeight.w800)),
                CoinPill(coins: app.coins, theme: t),
              ],
            ),
            const SizedBox(height: 4),
            Text('Fill the lines. Watch them bloom.', style: t.body(14)),
            const SizedBox(height: 28),

            // Classic
            SectionCard(
              theme: t,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grid_view_rounded, color: t.accent),
                      const SizedBox(width: 8),
                      Text('Classic', style: t.title(18)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Endless. Score as high as you can.', style: t.body(13)),
                  const SizedBox(height: 4),
                  Text('Best: ${app.bestClassic}',
                      style: t.body(13, weight: FontWeight.w700, color: t.text)),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Play',
                    theme: t,
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GameScreen(mode: GameMode.classic),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily challenge
            SectionCard(
              theme: t,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: t.gold),
                      const SizedBox(width: 8),
                      Text('Daily Challenge', style: t.title(18)),
                      const Spacer(),
                      if (app.dailyStreak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.gold.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('🔥 ${app.dailyStreak}',
                              style: TextStyle(
                                  color: t.gold, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Same board as everyone else, today only.',
                      style: t.body(13)),
                  const SizedBox(height: 4),
                  Text('Today\'s best: ${app.bestDailyFor(today)}',
                      style: t.body(13, weight: FontWeight.w700, color: t.text)),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: app.dailyDoneToday ? 'Play again' : 'Play today\'s board',
                    theme: t,
                    icon: Icons.bolt_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          mode: GameMode.daily,
                          day: today,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

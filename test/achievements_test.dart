import 'package:block_bloom/app/achievements.dart';
import 'package:block_bloom/app/app_state.dart';
import 'package:block_bloom/app/missions.dart';
import 'package:block_bloom/app/rewards.dart';
import 'package:block_bloom/game/engine.dart';
import 'package:block_bloom/game/levels.dart';
import 'package:block_bloom/game/powerups.dart';
import 'package:block_bloom/ui/achievement_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlacementResult move({int lines = 1, int combo = 1, bool allClear = false}) =>
    PlacementResult(
      placedCells: 2,
      clearedRows: List.generate(lines, (i) => i),
      clearedCols: const [],
      clearedCells: const {},
      clearedCellColors: const {},
      points: 0,
      comboAfter: combo,
      allClear: allClear,
    );

void main() {
  late List<String> unlocked;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'coins': 0});
    await AppState.load();
    unlocked = [];
    AppState.instance.onAchievementUnlocked = (a) => unlocked.add(a.id);
  });

  test('achievement ids are unique', () {
    final ids = AchievementTracker.all.map((a) => a.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('combos, big clears and all-clears unlock as they happen, paying coins', () {
    final app = AppState.instance;
    app.reportMove(move(combo: 3));
    expect(unlocked, contains('combo_3'));
    expect(unlocked, contains('first_clear').negate());

    app.reportMove(move(lines: 3, combo: 6, allClear: true));
    expect(unlocked, containsAll(['combo_6', 'big_clear', 'all_clear']));
    final paid = AchievementTracker.all
        .where((a) => unlocked.contains(a.id))
        .fold<int>(0, (s, a) => s + a.coinReward);
    expect(app.coins, paid);

    // Each unlocks only once.
    final n = unlocked.length;
    app.reportMove(move(combo: 9, allClear: true));
    expect(unlocked.length, n);
  });

  test('power-ups, spins, levels, stars and login weeks all count', () {
    final app = AppState.instance;
    app.addPowerUp(PowerUp.bomb, 20);
    for (var i = 0; i < 10; i++) {
      app.usePowerUp(PowerUp.bomb);
    }
    expect(unlocked, contains('powerups_10'));

    for (var i = 0; i < 10; i++) {
      app.recordSpin(const Reward(coins: 1), viaAd: true);
    }
    expect(unlocked, contains('spins_10'));

    app.completeLevel(Levels.get(1), 3);
    expect(unlocked, contains('level_1'));
    expect(AchievementTracker.instance.counter(Counter.stars), 3);
    // Replaying a won level doesn't count as another win.
    app.completeLevel(Levels.get(1), 3);
    expect(AchievementTracker.instance.counter(Counter.levelsWon), 1);

    var now = DateTime(2026, 11, 26, 9);
    app.clock = () => now;
    for (var d = 0; d < 7; d++) {
      app.claimLoginReward();
      now = now.add(const Duration(days: 1));
    }
    expect(unlocked, contains('login_7'));
    app.clock = DateTime.now;
  });

  test('new mission metrics track progress', () {
    final m = Missions.instance;
    m.today = const [
      Mission(id: 'c', title: '', target: 5, reward: 1, metric: MissionMetric.comboReached),
      Mission(id: 'p', title: '', target: 2, reward: 1, metric: MissionMetric.powerUpsUsed),
      Mission(id: 'l', title: '', target: 1, reward: 1, metric: MissionMetric.levelsWon),
      Mission(id: 'd', title: '', target: 1, reward: 1, metric: MissionMetric.dailyPlayed),
    ];
    final app = AppState.instance;
    app.reportMove(move(combo: 4));
    app.reportMove(move(combo: 2));
    expect(m.progressOf(m.today[0]), 4, reason: 'combo keeps the max');
    app.usePowerUp(PowerUp.undo);
    app.usePowerUp(PowerUp.undo);
    expect(m.isComplete(m.today[1]), isTrue);
    app.completeLevel(Levels.get(1), 1);
    expect(m.isComplete(m.today[2]), isTrue);
    m.reportEvent(MissionMetric.dailyPlayed);
    expect(m.isComplete(m.today[3]), isTrue);
  });

  testWidgets('the unlock banner slides in and goes away', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: AchievementBannerHost(child: Scaffold())));
    AchievementToasts.show(AchievementTracker.all.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ACHIEVEMENT UNLOCKED'), findsOneWidget);
    expect(find.text(AchievementTracker.all.first.title), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('ACHIEVEMENT UNLOCKED'), findsNothing);
  });
}

extension on Matcher {
  Matcher negate() => isNot(this);
}

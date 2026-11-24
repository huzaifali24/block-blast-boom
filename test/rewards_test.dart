import 'dart:math';

import 'package:block_bloom/app/app_state.dart';
import 'package:block_bloom/app/rewards.dart';
import 'package:block_bloom/game/powerups.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'coins': 0});
    await AppState.load();
    now = DateTime(2026, 11, 25, 9);
    AppState.instance.clock = () => now;
  });

  test('login streak climbs day by day and loops after day 7', () {
    final app = AppState.instance;
    for (var d = 1; d <= 7; d++) {
      expect(app.loginRewardReady, isTrue);
      expect(app.loginStreakDay, d);
      app.claimLoginReward();
      expect(app.loginRewardReady, isFalse, reason: 'once per day');
      expect(app.claimLoginReward(), isNull);
      now = now.add(const Duration(days: 1));
    }
    expect(app.loginStreakDay, 1); // looped
  });

  test('missing a day restarts the streak', () {
    final app = AppState.instance;
    app.claimLoginReward(); // day 1
    now = now.add(const Duration(days: 1));
    app.claimLoginReward(); // day 2
    now = now.add(const Duration(days: 3));
    expect(app.loginStreakDay, 1);
  });

  test('claiming grants the exact coins and power-ups', () {
    final app = AppState.instance;
    final bombs = app.powerUpCount(PowerUp.bomb);
    for (var d = 1; d <= 7; d++) {
      app.claimLoginReward();
      now = now.add(const Duration(days: 1));
    }
    final coins = LoginCalendar.days.fold<int>(0, (a, r) => a + r.coins);
    expect(app.coins, coins);
    expect(app.powerUpCount(PowerUp.bomb), bombs + 1 + 2);
  });

  test('one free spin a day plus limited ad spins, reset at midnight', () {
    final app = AppState.instance;
    expect(app.freeSpinReady, isTrue);
    app.recordSpin(const Reward(coins: 25), viaAd: false);
    expect(app.freeSpinReady, isFalse);
    for (var i = 0; i < LuckyWheel.adSpinsPerDay; i++) {
      app.recordSpin(const Reward(coins: 25), viaAd: true);
    }
    expect(app.adSpinsLeft, 0);
    expect(app.coins, 25 * (1 + LuckyWheel.adSpinsPerDay));

    now = now.add(const Duration(days: 1));
    expect(app.freeSpinReady, isTrue);
    expect(app.adSpinsLeft, LuckyWheel.adSpinsPerDay);
  });

  test('wheel odds favour small prizes', () {
    final rng = Random(1);
    final hits = List.filled(LuckyWheel.slices.length, 0);
    for (var i = 0; i < 20000; i++) {
      hits[LuckyWheel.spin(rng)]++;
    }
    final jackpot = LuckyWheel.slices.indexWhere((s) => s.reward.coins == 250);
    final small = LuckyWheel.slices.indexWhere((s) => s.reward.coins == 25);
    expect(hits[jackpot], lessThan(hits[small] ~/ 4));
    expect(hits.every((h) => h > 0), isTrue);
  });
}

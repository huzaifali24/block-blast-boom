import 'dart:math';

import '../game/powerups.dart';

/// A bundle of coins and/or power-ups.
class Reward {
  const Reward({this.coins = 0, this.items = const {}});
  final int coins;
  final Map<PowerUp, int> items;

  String get label {
    final parts = <String>[
      if (coins > 0) '$coins coins',
      for (final e in items.entries) '${e.value} ${e.key.label}',
    ];
    return parts.join(' + ');
  }
}

/// The 7-day login calendar. Claim once per calendar day; a missed day
/// restarts at day 1; after day 7 it loops.
class LoginCalendar {
  LoginCalendar._();

  static const days = [
    Reward(coins: 50),
    Reward(coins: 50, items: {PowerUp.undo: 1}),
    Reward(coins: 100),
    Reward(items: {PowerUp.bomb: 1, PowerUp.rotate: 1}),
    Reward(coins: 150),
    Reward(items: {PowerUp.shuffle: 1, PowerUp.undo: 1, PowerUp.rotate: 1}),
    Reward(coins: 300, items: {PowerUp.bomb: 2}),
  ];

  /// Days since an arbitrary epoch for a local calendar date.
  static int dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// Whether a reward can be claimed [today] given the last claim day.
  static bool canClaim({required int? lastClaimDay, required int today}) =>
      lastClaimDay == null || lastClaimDay < today;

  /// Which calendar day (1..7) today's claim is.
  static int nextStreakDay({
    required int? lastClaimDay,
    required int lastStreakDay,
    required int today,
  }) {
    if (lastClaimDay == null) return 1;
    if (lastClaimDay == today) return lastStreakDay; // already claimed
    if (lastClaimDay == today - 1) return lastStreakDay % days.length + 1;
    return 1; // missed a day
  }
}

/// One slice of the lucky wheel.
class WheelSlice {
  const WheelSlice(this.reward, this.weight);
  final Reward reward;
  final int weight;
}

/// The lucky wheel: one free spin a day, more by watching ads.
class LuckyWheel {
  LuckyWheel._();

  static const freeSpinsPerDay = 1;
  static const adSpinsPerDay = 3;

  static const slices = [
    WheelSlice(Reward(coins: 25), 22),
    WheelSlice(Reward(items: {PowerUp.undo: 1}), 14),
    WheelSlice(Reward(coins: 50), 18),
    WheelSlice(Reward(items: {PowerUp.bomb: 1}), 10),
    WheelSlice(Reward(coins: 100), 10),
    WheelSlice(Reward(items: {PowerUp.rotate: 1}), 14),
    WheelSlice(Reward(coins: 250), 3),
    WheelSlice(Reward(items: {PowerUp.shuffle: 1}), 9),
  ];

  /// Picks a slice index, weighted (big prizes are rarer).
  static int spin(Random rng) {
    final total = slices.fold<int>(0, (a, s) => a + s.weight);
    var roll = rng.nextInt(total);
    for (var i = 0; i < slices.length; i++) {
      roll -= slices[i].weight;
      if (roll < 0) return i;
    }
    return 0;
  }
}

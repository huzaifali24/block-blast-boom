import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lifetime counters achievements are checked against, beyond the basic
/// score/lines/games totals.
class Counter {
  Counter._();
  static const maxCombo = 'max_combo';
  static const allClears = 'all_clears';
  static const bigClears = 'big_clears'; // 3+ lines in one move
  static const powerUpsUsed = 'powerups_used';
  static const spins = 'spins';
  static const levelsWon = 'levels_won';
  static const stars = 'stars';
  static const dailyPlayed = 'daily_played';
  static const loginWeeks = 'login_weeks'; // full 7-day streaks claimed
}

/// Rolling stats an [AchievementDef] can be checked against.
class AchievementStats {
  const AchievementStats({
    required this.lastScore,
    required this.bestClassic,
    required this.totalLinesCleared,
    required this.gamesPlayed,
    required this.coins,
    this.counters = const {},
  });

  final int lastScore;
  final int bestClassic;
  final int totalLinesCleared;
  final int gamesPlayed;
  final int coins;
  final Map<String, int> counters;

  int c(String key) => counters[key] ?? 0;
}

/// One unlockable trophy. Named `AchievementDef` (not `Achievement`) to
/// avoid clashing with the `games_services` package's own `Achievement`
/// class, which `play_games.dart` also needs.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.coinReward,
    required this.check,
  });

  final String id;
  final String title;
  final String description;
  final int coinReward;
  final bool Function(AchievementStats stats) check;
}

/// Tracks lifetime stats and which achievements have unlocked, persisted
/// locally. Stats update as things happen ([bump]/[raise]) and at the end
/// of each game ([reportGame]); [evaluate] returns anything newly earned.
class AchievementTracker {
  AchievementTracker._();
  static final instance = AchievementTracker._();

  static const _kUnlocked = 'ach_unlocked';
  static const _kLines = 'ach_total_lines';
  static const _kGames = 'ach_total_games';
  static const _kCounters = 'ach_counters';

  late SharedPreferences _prefs;
  Set<String> unlocked = {};
  int totalLinesCleared = 0;
  int gamesPlayed = 0;
  Map<String, int> counters = {};
  int _lastScore = 0;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    unlocked = (prefs.getStringList(_kUnlocked) ?? const []).toSet();
    totalLinesCleared = prefs.getInt(_kLines) ?? 0;
    gamesPlayed = prefs.getInt(_kGames) ?? 0;
    final raw = prefs.getString(_kCounters);
    counters = raw == null
        ? {}
        : (jsonDecode(raw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int));
    _lastScore = 0;
  }

  static final all = <AchievementDef>[
    // --- Classic ---------------------------------------------------------
    AchievementDef(
      id: 'first_clear',
      title: 'First Clear',
      description: 'Clear your first line.',
      coinReward: 25,
      check: (s) => s.totalLinesCleared >= 1,
    ),
    AchievementDef(
      id: 'score_500',
      title: 'Getting Going',
      description: 'Score 500 in a single game.',
      coinReward: 40,
      check: (s) => s.lastScore >= 500,
    ),
    AchievementDef(
      id: 'score_1500',
      title: 'Blockbuster',
      description: 'Score 1,500 in a single game.',
      coinReward: 80,
      check: (s) => s.lastScore >= 1500,
    ),
    AchievementDef(
      id: 'score_3000',
      title: 'Grandmaster',
      description: 'Score 3,000 in a single game.',
      coinReward: 150,
      check: (s) => s.lastScore >= 3000,
    ),
    AchievementDef(
      id: 'lines_50',
      title: 'Line Cook',
      description: 'Clear 50 lines in total.',
      coinReward: 60,
      check: (s) => s.totalLinesCleared >= 50,
    ),
    AchievementDef(
      id: 'lines_250',
      title: 'Demolition Crew',
      description: 'Clear 250 lines in total.',
      coinReward: 120,
      check: (s) => s.totalLinesCleared >= 250,
    ),
    AchievementDef(
      id: 'lines_1000',
      title: 'Wrecking Ball',
      description: 'Clear 1,000 lines in total.',
      coinReward: 250,
      check: (s) => s.totalLinesCleared >= 1000,
    ),
    AchievementDef(
      id: 'games_10',
      title: 'Regular',
      description: 'Play 10 games.',
      coinReward: 40,
      check: (s) => s.gamesPlayed >= 10,
    ),
    AchievementDef(
      id: 'games_100',
      title: 'Dedicated',
      description: 'Play 100 games.',
      coinReward: 150,
      check: (s) => s.gamesPlayed >= 100,
    ),
    AchievementDef(
      id: 'coins_1000',
      title: 'Piggy Bank',
      description: 'Hold 1,000 coins at once.',
      coinReward: 50,
      check: (s) => s.coins >= 1000,
    ),
    // --- Combos & clears --------------------------------------------------
    AchievementDef(
      id: 'combo_3',
      title: 'Chain Reaction',
      description: 'Reach a 3x combo.',
      coinReward: 40,
      check: (s) => s.c(Counter.maxCombo) >= 3,
    ),
    AchievementDef(
      id: 'combo_6',
      title: 'Unstoppable',
      description: 'Reach a 6x combo.',
      coinReward: 120,
      check: (s) => s.c(Counter.maxCombo) >= 6,
    ),
    AchievementDef(
      id: 'big_clear',
      title: 'Triple Threat',
      description: 'Clear 3 or more lines in one move.',
      coinReward: 60,
      check: (s) => s.c(Counter.bigClears) >= 1,
    ),
    AchievementDef(
      id: 'all_clear',
      title: 'Clean Sweep',
      description: 'Clear the whole board.',
      coinReward: 100,
      check: (s) => s.c(Counter.allClears) >= 1,
    ),
    AchievementDef(
      id: 'all_clear_10',
      title: 'Spotless',
      description: 'Clear the whole board 10 times.',
      coinReward: 250,
      check: (s) => s.c(Counter.allClears) >= 10,
    ),
    // --- Adventure --------------------------------------------------------
    AchievementDef(
      id: 'level_1',
      title: 'Adventurer',
      description: 'Win your first Adventure level.',
      coinReward: 30,
      check: (s) => s.c(Counter.levelsWon) >= 1,
    ),
    AchievementDef(
      id: 'level_10',
      title: 'Explorer',
      description: 'Win 10 Adventure levels.',
      coinReward: 120,
      check: (s) => s.c(Counter.levelsWon) >= 10,
    ),
    AchievementDef(
      id: 'level_30',
      title: 'Legend',
      description: 'Win all 30 Adventure levels.',
      coinReward: 400,
      check: (s) => s.c(Counter.levelsWon) >= 30,
    ),
    AchievementDef(
      id: 'stars_45',
      title: 'Star Collector',
      description: 'Earn 45 Adventure stars.',
      coinReward: 200,
      check: (s) => s.c(Counter.stars) >= 45,
    ),
    AchievementDef(
      id: 'stars_90',
      title: 'Perfectionist',
      description: 'Earn all 90 Adventure stars.',
      coinReward: 500,
      check: (s) => s.c(Counter.stars) >= 90,
    ),
    // --- Extras -----------------------------------------------------------
    AchievementDef(
      id: 'powerups_10',
      title: 'Tactician',
      description: 'Use 10 power-ups.',
      coinReward: 60,
      check: (s) => s.c(Counter.powerUpsUsed) >= 10,
    ),
    AchievementDef(
      id: 'spins_10',
      title: 'Lucky Streak',
      description: 'Spin the Lucky Wheel 10 times.',
      coinReward: 50,
      check: (s) => s.c(Counter.spins) >= 10,
    ),
    AchievementDef(
      id: 'daily_7',
      title: 'Daily Devotee',
      description: 'Play 7 Daily Challenges.',
      coinReward: 100,
      check: (s) => s.c(Counter.dailyPlayed) >= 7,
    ),
    AchievementDef(
      id: 'login_7',
      title: 'Week Warrior',
      description: 'Claim all 7 days of Daily Rewards.',
      coinReward: 120,
      check: (s) => s.c(Counter.loginWeeks) >= 1,
    ),
  ];

  bool isUnlocked(AchievementDef a) => unlocked.contains(a.id);

  /// Replaces lifetime stats with merged cloud-save values.
  void restore({
    required Set<String> unlocked,
    required Map<String, int> counters,
    required int totalLines,
    required int gamesPlayed,
  }) {
    this.unlocked = Set.of(unlocked);
    this.counters = Map.of(counters);
    totalLinesCleared = totalLines;
    this.gamesPlayed = gamesPlayed;
    _prefs.setStringList(_kUnlocked, this.unlocked.toList());
    _prefs.setInt(_kLines, totalLinesCleared);
    _prefs.setInt(_kGames, this.gamesPlayed);
    _saveCounters();
  }

  int counter(String key) => counters[key] ?? 0;

  /// Adds [by] to a lifetime counter.
  void bump(String key, [int by = 1]) {
    counters[key] = counter(key) + by;
    _saveCounters();
  }

  /// Raises a lifetime counter to [value] if that's higher.
  void raise(String key, int value) {
    if (value <= counter(key)) return;
    counters[key] = value;
    _saveCounters();
  }

  void _saveCounters() => _prefs.setString(_kCounters, jsonEncode(counters));

  /// Unlocks anything the current stats now satisfy. Returns the
  /// achievements that unlocked *this call* (empty most of the time).
  List<AchievementDef> evaluate({required int bestClassic, required int coins}) {
    final stats = AchievementStats(
      lastScore: _lastScore,
      bestClassic: bestClassic,
      totalLinesCleared: totalLinesCleared,
      gamesPlayed: gamesPlayed,
      coins: coins,
      counters: counters,
    );
    final newly = <AchievementDef>[];
    for (final a in all) {
      if (!unlocked.contains(a.id) && a.check(stats)) {
        unlocked.add(a.id);
        newly.add(a);
      }
    }
    if (newly.isNotEmpty) {
      _prefs.setStringList(_kUnlocked, unlocked.toList());
    }
    return newly;
  }

  /// Updates lifetime totals after a finished game and unlocks anything
  /// newly earned.
  List<AchievementDef> reportGame({
    required int score,
    required int linesCleared,
    required int bestClassic,
    required int coins,
  }) {
    totalLinesCleared += linesCleared;
    gamesPlayed += 1;
    _prefs.setInt(_kLines, totalLinesCleared);
    _prefs.setInt(_kGames, gamesPlayed);
    _lastScore = score;
    final newly = evaluate(bestClassic: bestClassic, coins: coins);
    _lastScore = 0;
    return newly;
  }
}

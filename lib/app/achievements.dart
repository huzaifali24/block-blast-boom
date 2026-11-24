import 'package:shared_preferences/shared_preferences.dart';

/// Rolling stats an [AchievementDef] can be checked against. Built fresh by
/// [AchievementTracker.reportGame] after every finished game.
class AchievementStats {
  const AchievementStats({
    required this.lastScore,
    required this.bestClassic,
    required this.totalLinesCleared,
    required this.gamesPlayed,
    required this.coins,
  });

  final int lastScore;
  final int bestClassic;
  final int totalLinesCleared;
  final int gamesPlayed;
  final int coins;
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
/// locally. [AppState.recordGameResult] calls [reportGame] once per finished
/// game and folds any coin rewards into the player's balance.
class AchievementTracker {
  AchievementTracker._();
  static final instance = AchievementTracker._();

  static const _kUnlocked = 'ach_unlocked';
  static const _kLines = 'ach_total_lines';
  static const _kGames = 'ach_total_games';

  late SharedPreferences _prefs;
  Set<String> unlocked = {};
  int totalLinesCleared = 0;
  int gamesPlayed = 0;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    unlocked = (prefs.getStringList(_kUnlocked) ?? const []).toSet();
    totalLinesCleared = prefs.getInt(_kLines) ?? 0;
    gamesPlayed = prefs.getInt(_kGames) ?? 0;
  }

  static final all = <AchievementDef>[
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
  ];

  bool isUnlocked(AchievementDef a) => unlocked.contains(a.id);

  /// Updates lifetime totals and unlocks anything newly earned. Returns the
  /// achievements that unlocked *this call* (empty most of the time).
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

    final stats = AchievementStats(
      lastScore: score,
      bestClassic: bestClassic,
      totalLinesCleared: totalLinesCleared,
      gamesPlayed: gamesPlayed,
      coins: coins,
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
}

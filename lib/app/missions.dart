import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/modes.dart';

enum MissionMetric {
  linesCleared,
  scoreInOneGame,
  piecesPlaced,
  gamesPlayed,

  /// Highest combo reached today (a max, not a sum).
  comboReached,
  levelsWon,
  powerUpsUsed,
  dailyPlayed,
}

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.target,
    required this.reward,
    required this.metric,
  });

  final String id;
  final String title;
  final int target;
  final int reward;
  final MissionMetric metric;
}

/// Three daily tasks, reshuffled every calendar day from a pool, seeded so
/// every player gets the same three on the same day. Progress and claims
/// reset the first time the game is opened on a new day.
class Missions {
  Missions._();
  static final instance = Missions._();

  static const _kDaySeed = 'missions_day_seed';
  static const _kProgress = 'missions_progress';
  static const _kClaimed = 'missions_claimed';

  late SharedPreferences _prefs;
  List<Mission> today = const [];
  Map<String, int> progress = {};
  Set<String> claimed = {};

  static final _pool = <Mission>[
    Mission(
        id: 'lines6',
        title: 'Clear 6 lines',
        target: 6,
        reward: 40,
        metric: MissionMetric.linesCleared),
    Mission(
        id: 'lines15',
        title: 'Clear 15 lines',
        target: 15,
        reward: 70,
        metric: MissionMetric.linesCleared),
    Mission(
        id: 'lines30',
        title: 'Clear 30 lines',
        target: 30,
        reward: 110,
        metric: MissionMetric.linesCleared),
    Mission(
        id: 'score300',
        title: 'Score 300 in one game',
        target: 300,
        reward: 50,
        metric: MissionMetric.scoreInOneGame),
    Mission(
        id: 'score600',
        title: 'Score 600 in one game',
        target: 600,
        reward: 90,
        metric: MissionMetric.scoreInOneGame),
    Mission(
        id: 'score1200',
        title: 'Score 1,200 in one game',
        target: 1200,
        reward: 140,
        metric: MissionMetric.scoreInOneGame),
    Mission(
        id: 'pieces20',
        title: 'Place 20 pieces',
        target: 20,
        reward: 30,
        metric: MissionMetric.piecesPlaced),
    Mission(
        id: 'pieces60',
        title: 'Place 60 pieces',
        target: 60,
        reward: 80,
        metric: MissionMetric.piecesPlaced),
    Mission(
        id: 'games2',
        title: 'Play 2 games',
        target: 2,
        reward: 25,
        metric: MissionMetric.gamesPlayed),
    Mission(
        id: 'games5',
        title: 'Play 5 games',
        target: 5,
        reward: 55,
        metric: MissionMetric.gamesPlayed),
    Mission(
        id: 'combo3',
        title: 'Reach a 3x combo',
        target: 3,
        reward: 60,
        metric: MissionMetric.comboReached),
    Mission(
        id: 'combo5',
        title: 'Reach a 5x combo',
        target: 5,
        reward: 120,
        metric: MissionMetric.comboReached),
    Mission(
        id: 'level1',
        title: 'Win an Adventure level',
        target: 1,
        reward: 50,
        metric: MissionMetric.levelsWon),
    Mission(
        id: 'level3',
        title: 'Win 3 Adventure levels',
        target: 3,
        reward: 100,
        metric: MissionMetric.levelsWon),
    Mission(
        id: 'power2',
        title: 'Use 2 power-ups',
        target: 2,
        reward: 40,
        metric: MissionMetric.powerUpsUsed),
    Mission(
        id: 'daily1',
        title: 'Play the Daily Challenge',
        target: 1,
        reward: 40,
        metric: MissionMetric.dailyPlayed),
  ];

  static List<Mission> _generate(int seed) {
    final picked = [..._pool]..shuffle(Random(seed));
    return picked.take(3).toList();
  }

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    final todaySeed = DailyChallenge.seedFor(DateTime.now());
    final storedSeed = prefs.getInt(_kDaySeed);
    today = _generate(todaySeed);
    if (storedSeed != todaySeed) {
      progress = {};
      claimed = {};
      await prefs.setInt(_kDaySeed, todaySeed);
      await _persist();
    } else {
      final raw = prefs.getString(_kProgress);
      progress = raw == null
          ? {}
          : (jsonDecode(raw) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v as int));
      claimed = (prefs.getStringList(_kClaimed) ?? const []).toSet();
    }
  }

  bool isComplete(Mission m) => (progress[m.id] ?? 0) >= m.target;
  bool isClaimed(Mission m) => claimed.contains(m.id);
  int progressOf(Mission m) => progress[m.id] ?? 0;

  void reportGame({
    required int score,
    required int linesCleared,
    required int piecesPlaced,
  }) {
    for (final m in today) {
      final current = progress[m.id] ?? 0;
      if (m.metric == MissionMetric.linesCleared) {
        progress[m.id] = current + linesCleared;
      } else if (m.metric == MissionMetric.scoreInOneGame) {
        progress[m.id] = max(current, score);
      } else if (m.metric == MissionMetric.piecesPlaced) {
        progress[m.id] = current + piecesPlaced;
      } else if (m.metric == MissionMetric.gamesPlayed) {
        progress[m.id] = current + 1;
      }
    }
    _persist();
  }

  /// Records something that happened outside the end-of-game report:
  /// [value] is added, or for [MissionMetric.comboReached] kept as a max.
  void reportEvent(MissionMetric metric, [int value = 1]) {
    var changed = false;
    for (final m in today) {
      if (m.metric != metric) continue;
      final current = progress[m.id] ?? 0;
      final next = metric == MissionMetric.comboReached
          ? max(current, value)
          : current + value;
      if (next != current) {
        progress[m.id] = next;
        changed = true;
      }
    }
    if (changed) _persist();
  }

  /// Claims a completed mission's reward. Returns the coin amount granted,
  /// or 0 if it isn't complete yet or was already claimed.
  int claim(Mission m) {
    if (!isComplete(m) || isClaimed(m)) return 0;
    claimed.add(m.id);
    _persist();
    return m.reward;
  }

  Future<void> _persist() async {
    await _prefs.setString(_kProgress, jsonEncode(progress));
    await _prefs.setStringList(_kClaimed, claimed.toList());
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// Everything worth keeping across phones, as plain data.
@immutable
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.savedAt,
    required this.coins,
    required this.powerUps,
    required this.bestClassic,
    required this.levelStars,
    required this.ownedThemes,
    required this.ownedSkins,
    required this.adsRemoved,
    required this.tutorialDone,
    required this.theme,
    required this.skin,
    required this.achievements,
    required this.counters,
    required this.totalLines,
    required this.gamesPlayed,
  });

  /// When the wallet (coins/power-ups) last changed; 0 = never played.
  final int savedAt;
  final int coins;
  final Map<String, int> powerUps;
  final int bestClassic;
  final Map<int, int> levelStars;
  final Set<String> ownedThemes;
  final Set<String> ownedSkins;
  final bool adsRemoved;
  final bool tutorialDone;
  final String theme;
  final String skin;
  final Set<String> achievements;
  final Map<String, int> counters;
  final int totalLines;
  final int gamesPlayed;

  /// No real play yet (a fresh install, maybe holding only starter gifts).
  bool get isFresh => gamesPlayed == 0 && levelStars.isEmpty;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'savedAt': savedAt,
        'coins': coins,
        'powerUps': powerUps,
        'bestClassic': bestClassic,
        'levelStars': levelStars.map((k, v) => MapEntry('$k', v)),
        'ownedThemes': ownedThemes.toList()..sort(),
        'ownedSkins': ownedSkins.toList()..sort(),
        'adsRemoved': adsRemoved,
        'tutorialDone': tutorialDone,
        'theme': theme,
        'skin': skin,
        'achievements': achievements.toList()..sort(),
        'counters': counters,
        'totalLines': totalLines,
        'gamesPlayed': gamesPlayed,
      };

  factory ProgressSnapshot.fromJson(Map<String, dynamic> j) {
    Map<String, int> ints(Object? o) => (o as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(k, (v as num).toInt()));
    Set<String> strs(Object? o) =>
        (o as List<dynamic>? ?? const []).map((e) => '$e').toSet();
    return ProgressSnapshot(
      savedAt: (j['savedAt'] as num?)?.toInt() ?? 0,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      powerUps: ints(j['powerUps']),
      bestClassic: (j['bestClassic'] as num?)?.toInt() ?? 0,
      levelStars: ints(j['levelStars']).map((k, v) => MapEntry(int.parse(k), v)),
      ownedThemes: strs(j['ownedThemes']),
      ownedSkins: strs(j['ownedSkins']),
      adsRemoved: j['adsRemoved'] == true,
      tutorialDone: j['tutorialDone'] == true,
      theme: j['theme'] as String? ?? '',
      skin: j['skin'] as String? ?? '',
      achievements: strs(j['achievements']),
      counters: ints(j['counters']),
      totalLines: (j['totalLines'] as num?)?.toInt() ?? 0,
      gamesPlayed: (j['gamesPlayed'] as num?)?.toInt() ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());
  static ProgressSnapshot decode(String s) =>
      ProgressSnapshot.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Combines two saves without ever losing what the player earned:
  /// records (bests, stars, unlocks, purchases, achievements, lifetime
  /// stats) take the max/union; the spendable wallet (coins, power-ups)
  /// and cosmetic choices come from the newer save, except that a fresh
  /// install always defers to a real save.
  static ProgressSnapshot merge(ProgressSnapshot a, ProgressSnapshot b) {
    final ProgressSnapshot wallet;
    if (a.isFresh != b.isFresh) {
      wallet = a.isFresh ? b : a;
    } else {
      wallet = a.savedAt >= b.savedAt ? a : b;
    }
    Map<K, int> maxMap<K>(Map<K, int> x, Map<K, int> y) => {
          for (final k in {...x.keys, ...y.keys}) k: max(x[k] ?? 0, y[k] ?? 0),
        };
    return ProgressSnapshot(
      savedAt: max(a.savedAt, b.savedAt),
      coins: wallet.coins,
      powerUps: Map.of(wallet.powerUps),
      bestClassic: max(a.bestClassic, b.bestClassic),
      levelStars: maxMap(a.levelStars, b.levelStars),
      ownedThemes: {...a.ownedThemes, ...b.ownedThemes},
      ownedSkins: {...a.ownedSkins, ...b.ownedSkins},
      adsRemoved: a.adsRemoved || b.adsRemoved,
      tutorialDone: a.tutorialDone || b.tutorialDone,
      theme: wallet.theme,
      skin: wallet.skin,
      achievements: {...a.achievements, ...b.achievements},
      counters: maxMap(a.counters, b.counters),
      totalLines: max(a.totalLines, b.totalLines),
      gamesPlayed: max(a.gamesPlayed, b.gamesPlayed),
    );
  }
}

/// Where local progress comes from and goes back to (AppState in the app,
/// a fake in tests).
abstract class ProgressStore {
  ProgressSnapshot snapshot();
  void apply(ProgressSnapshot s);
}

/// Where cloud saves live (Play Games saved games in the app).
abstract class CloudBackend {
  bool get available;
  Future<String?> load(String name);
  Future<void> save(String name, String data);
}

class PlayGamesCloud implements CloudBackend {
  PlayGamesCloud(this._signedIn);
  final bool Function() _signedIn;

  @override
  bool get available =>
      _signedIn() && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> load(String name) => SaveGame.loadGame(name: name);

  @override
  Future<void> save(String name, String data) =>
      SaveGame.saveGame(data: data, name: name, description: 'Block Boom progress');
}

/// Keeps local progress and the cloud save in step: [sync] on sign-in
/// (pull, merge, push), [schedule] after progress changes (debounced push
/// of the merged state).
class CloudSave {
  CloudSave(this.store, this.backend);

  static const slot = 'progress';
  static const debounce = Duration(seconds: 5);

  final ProgressStore store;
  final CloudBackend backend;
  Timer? _timer;
  bool _busy = false;

  /// Pulls the cloud save, merges it into local progress, pushes the result.
  Future<bool> sync() async {
    if (!backend.available || _busy) return false;
    _busy = true;
    try {
      var merged = store.snapshot();
      final raw = await backend.load(slot);
      if (raw != null && raw.isNotEmpty) {
        merged = ProgressSnapshot.merge(merged, ProgressSnapshot.decode(raw));
        store.apply(merged);
      }
      await backend.save(slot, merged.encode());
      return true;
    } catch (e) {
      debugPrint('Cloud save sync failed: $e');
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Requests a sync shortly (several changes in a row become one upload).
  void schedule() {
    if (!backend.available) return;
    _timer?.cancel();
    _timer = Timer(debounce, sync);
  }
}

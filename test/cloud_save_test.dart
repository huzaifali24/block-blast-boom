import 'package:block_bloom/app/achievements.dart';
import 'package:block_bloom/app/app_state.dart';
import 'package:block_bloom/app/cloud_save.dart';
import 'package:block_bloom/game/levels.dart';
import 'package:block_bloom/game/powerups.dart';
import 'package:block_bloom/game/skins.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProgressSnapshot snap({
  int savedAt = 1000,
  int coins = 100,
  Map<String, int> powerUps = const {'bomb': 2},
  int best = 0,
  Map<int, int> stars = const {},
  Set<String> skins = const {},
  bool adsRemoved = false,
  Set<String> ach = const {},
  Map<String, int> counters = const {},
  int games = 1,
}) =>
    ProgressSnapshot(
      savedAt: savedAt,
      coins: coins,
      powerUps: powerUps,
      bestClassic: best,
      levelStars: stars,
      ownedThemes: const {},
      ownedSkins: skins,
      adsRemoved: adsRemoved,
      tutorialDone: true,
      theme: 'Indigo',
      skin: 'classic',
      achievements: ach,
      counters: counters,
      totalLines: 0,
      gamesPlayed: games,
    );

class FakeCloud implements CloudBackend {
  String? data;
  int saves = 0;
  @override
  bool available = true;
  @override
  Future<String?> load(String name) async => data;
  @override
  Future<void> save(String name, String d) async {
    data = d;
    saves++;
  }
}

void main() {
  test('records only ever go up when merging', () {
    final phone = snap(best: 900, stars: {1: 3, 2: 1}, skins: {'wood'},
        ach: {'combo_3'}, counters: {Counter.allClears: 2});
    final cloud = snap(best: 1200, stars: {2: 3, 5: 2}, skins: {'neon_glow'},
        adsRemoved: true, ach: {'level_1'}, counters: {Counter.allClears: 5});
    final m = ProgressSnapshot.merge(phone, cloud);
    expect(m.bestClassic, 1200);
    expect(m.levelStars, {1: 3, 2: 3, 5: 2});
    expect(m.ownedSkins, {'wood', 'neon_glow'});
    expect(m.adsRemoved, isTrue);
    expect(m.achievements, {'combo_3', 'level_1'});
    expect(m.counters[Counter.allClears], 5);
    expect(ProgressSnapshot.merge(cloud, phone).toJson(), m.toJson(),
        reason: 'merge is order-independent');
  });

  test('the wallet comes from the newer save, never added together', () {
    final older = snap(savedAt: 1000, coins: 900, powerUps: {'bomb': 5});
    final newer = snap(savedAt: 2000, coins: 150, powerUps: {'bomb': 1});
    final m = ProgressSnapshot.merge(older, newer);
    expect(m.coins, 150);
    expect(m.powerUps['bomb'], 1);
  });

  test('a fresh install defers to a real save even if its clock is newer', () {
    final fresh = snap(savedAt: 9999, coins: 50, games: 0); // starter gifts
    final real = snap(savedAt: 10, coins: 4000, games: 120, stars: {1: 3});
    final m = ProgressSnapshot.merge(fresh, real);
    expect(m.coins, 4000);
    expect(m.levelStars, {1: 3});
  });

  test('snapshots survive the JSON round trip', () {
    final s = snap(stars: {3: 2}, skins: {'wood'}, ach: {'x'}, counters: {'k': 4});
    expect(ProgressSnapshot.decode(s.encode()).toJson(), s.toJson());
  });

  group('with the real app state', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'coins': 0});
      await AppState.load();
    });

    test('a new phone signing in gets its cloud progress back', () async {
      final cloud = FakeCloud()
        ..data = snap(
          coins: 2500,
          powerUps: {'bomb': 9, 'undo': 4, 'rotate': 1, 'shuffle': 0},
          best: 3100,
          stars: {1: 3, 2: 3, 3: 1},
          skins: {'wood'},
          ach: {'level_1', 'combo_3'},
          games: 80,
        ).encode();
      final sync = CloudSave(AppState.instance, cloud);
      expect(await sync.sync(), isTrue);

      final app = AppState.instance;
      expect(app.coins, 2500);
      expect(app.powerUpCount(PowerUp.bomb), 9);
      expect(app.bestClassic, 3100);
      expect(app.levelStars, {1: 3, 2: 3, 3: 1});
      expect(app.unlockedLevel, 4);
      expect(app.ownsSkin(Skins.wood), isTrue);
      expect(AchievementTracker.instance.unlocked, containsAll(['level_1', 'combo_3']));
      expect(cloud.saves, 1, reason: 'merged result is pushed back');

      // And it was persisted: a reload keeps it.
      await AppState.load();
      expect(AppState.instance.coins, 2500);
      expect(AppState.instance.levelStars[2], 3);
    });

    test('progress made on this phone is pushed to the cloud', () async {
      final cloud = FakeCloud();
      final app = AppState.instance;
      app.completeLevel(Levels.get(1), 2);
      final sync = CloudSave(app, cloud);
      await sync.sync();
      final saved = ProgressSnapshot.decode(cloud.data!);
      expect(saved.levelStars, {1: 2});
      expect(saved.coins, app.coins);
    });

    test('nothing happens when not signed in', () async {
      final cloud = FakeCloud()..available = false;
      expect(await CloudSave(AppState.instance, cloud).sync(), isFalse);
      expect(cloud.saves, 0);
    });
  });
}

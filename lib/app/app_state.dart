import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/modes.dart';
import '../game/powerups.dart';
import '../game/skins.dart';
import 'achievements.dart';
import 'missions.dart';
import 'music.dart';
import 'sound.dart';
import 'theme.dart';

/// Everything that happened at the end of a game, for the game-over sheet
/// and for anything else that wants to react (confetti, a toast, …).
class GameOutcome {
  const GameOutcome({
    required this.coinsEarned,
    required this.isNewBest,
    required this.newlyUnlocked,
  });

  final int coinsEarned;
  final bool isNewBest;
  final List<AchievementDef> newlyUnlocked;
}

/// The persisted-state hub: settings, currency, bests, and the small bits of
/// bookkeeping (daily streak, "have we asked for notification permission
/// yet") that don't belong to any one screen. Loaded once at startup with
/// [AppState.load]; everything else reads `AppState.instance` directly.
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  static const _kTheme = 'theme';
  static const _kSkin = 'skin';
  static const _kOwnedThemes = 'owned_themes';
  static const _kOwnedSkins = 'owned_skins';
  static const _kSound = 'sound_on';
  static const _kMusic = 'music_on';
  static const _kPowerUpPrefix = 'powerup_';
  static const _kHaptics = 'haptics_on';
  static const _kReminders = 'reminders_on';
  static const _kNotifAsked = 'notif_asked';
  static const _kCoins = 'coins';
  static const _kBestClassic = 'best_classic';
  static const _kBestDailyPrefix = 'best_daily_';
  static const _kAdsRemoved = 'ads_removed';
  static const _kDailyStreak = 'daily_streak';
  static const _kLastDailySeed = 'last_daily_seed';

  late SharedPreferences _prefs;

  AppTheme theme = AppTheme.indigo;
  BlockSkin skin = Skins.classic;
  Set<String> _ownedThemes = {};
  Set<String> _ownedSkins = {};

  bool soundOn = true;
  bool musicOn = true;
  bool hapticsOn = true;
  bool remindersOn = true;
  bool notifAsked = false;

  int coins = 0;
  final Map<PowerUp, int> powerUps = {};
  int bestClassic = 0;
  bool adsRemoved = false;

  int dailyStreak = 0;
  int? _lastDailySeed;

  bool get dailyDoneToday =>
      _lastDailySeed == DailyChallenge.seedFor(DateTime.now());

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final app = instance;
    app._prefs = prefs;

    app.theme =
        AppTheme.byName(prefs.getString(_kTheme) ?? AppTheme.indigo.name);
    app.skin = Skins.byId(prefs.getString(_kSkin) ?? Skins.classic.id);
    app._ownedThemes = (prefs.getStringList(_kOwnedThemes) ?? const []).toSet();
    app._ownedSkins = (prefs.getStringList(_kOwnedSkins) ?? const []).toSet();

    app.soundOn = prefs.getBool(_kSound) ?? true;
    Sound.instance.enabled = app.soundOn;
    app.musicOn = prefs.getBool(_kMusic) ?? true;
    app.hapticsOn = prefs.getBool(_kHaptics) ?? true;
    app.remindersOn = prefs.getBool(_kReminders) ?? true;
    app.notifAsked = prefs.getBool(_kNotifAsked) ?? false;

    app.coins = prefs.getInt(_kCoins) ?? 0;
    for (final p in PowerUp.values) {
      app.powerUps[p] =
          prefs.getInt('$_kPowerUpPrefix${p.name}') ?? PowerUp.starterCount;
    }
    app.bestClassic = prefs.getInt(_kBestClassic) ?? 0;
    app.adsRemoved = prefs.getBool(_kAdsRemoved) ?? false;

    app.dailyStreak = prefs.getInt(_kDailyStreak) ?? 0;
    app._lastDailySeed = prefs.getInt(_kLastDailySeed);

    await Missions.instance.load(prefs);
    await AchievementTracker.instance.load(prefs);
  }

  int bestDailyFor(DateTime day) =>
      _prefs.getInt('$_kBestDailyPrefix${DailyChallenge.seedFor(day)}') ?? 0;

  bool ownsTheme(AppTheme t) => t.price == 0 || _ownedThemes.contains(t.name);
  bool ownsSkin(BlockSkin s) => s.priceCoins == 0 || _ownedSkins.contains(s.id);

  /// Buys and immediately selects [t] if affordable (or already owned).
  /// Returns whether it's selected afterwards.
  bool buyOrSelectTheme(AppTheme t) {
    if (!ownsTheme(t)) {
      if (coins < t.price) return false;
      coins -= t.price;
      _ownedThemes = {..._ownedThemes, t.name};
      _prefs.setStringList(_kOwnedThemes, _ownedThemes.toList());
      _prefs.setInt(_kCoins, coins);
    }
    theme = t;
    _prefs.setString(_kTheme, t.name);
    notifyListeners();
    return true;
  }

  bool buyOrSelectSkin(BlockSkin s) {
    if (!ownsSkin(s)) {
      if (coins < s.priceCoins) return false;
      coins -= s.priceCoins;
      _ownedSkins = {..._ownedSkins, s.id};
      _prefs.setStringList(_kOwnedSkins, _ownedSkins.toList());
      _prefs.setInt(_kCoins, coins);
    }
    skin = s;
    _prefs.setString(_kSkin, s.id);
    notifyListeners();
    return true;
  }

  void addCoins(int amount) {
    if (amount == 0) return;
    coins += amount;
    _prefs.setInt(_kCoins, coins);
    notifyListeners();
  }

  int powerUpCount(PowerUp p) => powerUps[p] ?? 0;

  void addPowerUp(PowerUp p, [int n = 1]) {
    powerUps[p] = powerUpCount(p) + n;
    _prefs.setInt('$_kPowerUpPrefix${p.name}', powerUps[p]!);
    notifyListeners();
  }

  /// Spends one [p] if the player has any. Returns whether it was used.
  bool usePowerUp(PowerUp p) {
    if (powerUpCount(p) <= 0) return false;
    addPowerUp(p, -1);
    return true;
  }

  /// Buys one [p] for coins. Returns whether the purchase went through.
  bool buyPowerUp(PowerUp p) {
    if (!spendCoins(p.price)) return false;
    addPowerUp(p);
    return true;
  }

  bool spendCoins(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    _prefs.setInt(_kCoins, coins);
    notifyListeners();
    return true;
  }

  void setSoundOn(bool v) {
    soundOn = v;
    Sound.instance.enabled = v;
    _prefs.setBool(_kSound, v);
    notifyListeners();
  }

  void setMusicOn(bool v) {
    musicOn = v;
    Music.instance.setEnabled(v);
    _prefs.setBool(_kMusic, v);
    notifyListeners();
  }

  void setHapticsOn(bool v) {
    hapticsOn = v;
    _prefs.setBool(_kHaptics, v);
    notifyListeners();
  }

  void setRemindersOn(bool v) {
    remindersOn = v;
    _prefs.setBool(_kReminders, v);
    notifyListeners();
  }

  void setNotifAsked() {
    notifAsked = true;
    _prefs.setBool(_kNotifAsked, true);
  }

  void setAdsRemoved() {
    adsRemoved = true;
    _prefs.setBool(_kAdsRemoved, true);
    notifyListeners();
  }

  void _recordDailyPlayed(DateTime day) {
    final seed = DailyChallenge.seedFor(day);
    if (_lastDailySeed == seed) return; // Already counted today.
    final yesterdaySeed = DailyChallenge.seedFor(
        DateTime(day.year, day.month, day.day)
            .subtract(const Duration(days: 1)));
    dailyStreak = _lastDailySeed == yesterdaySeed ? dailyStreak + 1 : 1;
    _lastDailySeed = seed;
    _prefs.setInt(_kDailyStreak, dailyStreak);
    _prefs.setInt(_kLastDailySeed, seed);
  }

  /// Call once per finished game. Updates bests, mints coins, feeds the
  /// daily streak, missions and achievements, and persists all of it.
  GameOutcome recordGameResult({
    required GameMode mode,
    required int score,
    required int linesCleared,
    required int movesPlayed,
    required DateTime day,
  }) {
    var isNewBest = false;
    if (mode == GameMode.classic) {
      if (score > bestClassic) {
        bestClassic = score;
        isNewBest = true;
        _prefs.setInt(_kBestClassic, bestClassic);
      }
    } else {
      final key = '$_kBestDailyPrefix${DailyChallenge.seedFor(day)}';
      final prevBest = _prefs.getInt(key) ?? 0;
      if (score > prevBest) {
        isNewBest = true;
        _prefs.setInt(key, score);
      }
      _recordDailyPlayed(day);
    }

    var coinsEarned = (score / 20).floor() + linesCleared * 2;

    Missions.instance.reportGame(
      score: score,
      linesCleared: linesCleared,
      piecesPlaced: movesPlayed,
    );
    final unlocked = AchievementTracker.instance.reportGame(
      score: score,
      linesCleared: linesCleared,
      bestClassic: bestClassic,
      coins: coins,
    );
    for (final a in unlocked) {
      coinsEarned += a.coinReward;
    }

    coins += coinsEarned;
    _prefs.setInt(_kCoins, coins);
    notifyListeners();

    return GameOutcome(
      coinsEarned: coinsEarned,
      isNewBest: isNewBest,
      newlyUnlocked: unlocked,
    );
  }

  /// Claims a completed daily mission's reward, if any.
  int claimMission(Mission m) {
    final reward = Missions.instance.claim(m);
    if (reward > 0) addCoins(reward);
    return reward;
  }
}

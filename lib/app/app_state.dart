import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/board_painter.dart';
import '../game/engine.dart';
import '../game/levels.dart';
import '../game/modes.dart';
import '../game/powerups.dart';
import '../game/skins.dart';
import 'achievements.dart';
import 'cloud_save.dart';
import 'missions.dart';
import 'music.dart';
import 'play_games.dart';
import 'rewards.dart';
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
class AppState extends ChangeNotifier implements ProgressStore {
  AppState._();
  static final instance = AppState._();

  static const _kTheme = 'theme';
  static const _kSkin = 'skin';
  static const _kOwnedThemes = 'owned_themes';
  static const _kProgressAt = 'progress_at';
  static const _kOwnedSkins = 'owned_skins';
  static const _kSound = 'sound_on';
  static const _kMusic = 'music_on';
  static const _kPowerUpPrefix = 'powerup_';
  static const _kLevelStars = 'level_stars';
  static const _kTutorialDone = 'tutorial_done';
  static const _kLoginDay = 'login_last_day';
  static const _kLoginStreak = 'login_streak_day';
  static const _kSpinDay = 'spin_day';
  static const _kSpinsUsed = 'spins_used';
  static const _kAdSpinsUsed = 'ad_spins_used';
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

  /// When the wallet (coins / power-ups) last changed, for cloud merges.
  int _progressAt = 0;

  /// Syncs progress with the player's Play Games cloud save.
  late final CloudSave cloud =
      CloudSave(this, PlayGamesCloud(() => PlayGames.instance.signedIn));
  bool _applying = false;

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

  bool tutorialDone = false;
  int? _loginLastDay;
  int _loginStreakDay = 0;
  int? _spinDay;
  int _spinsUsed = 0;
  int _adSpinsUsed = 0;

  /// Adventure: level number -> best stars (1..3). Absent = not cleared.
  final Map<int, int> levelStars = {};
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
    BlockArt.style = app.skin.style;
    app._ownedThemes = (prefs.getStringList(_kOwnedThemes) ?? const []).toSet();
    app._ownedSkins = (prefs.getStringList(_kOwnedSkins) ?? const []).toSet();

    app.soundOn = prefs.getBool(_kSound) ?? true;
    Sound.instance.enabled = app.soundOn;
    app.musicOn = prefs.getBool(_kMusic) ?? true;
    app.hapticsOn = prefs.getBool(_kHaptics) ?? true;
    app.remindersOn = prefs.getBool(_kReminders) ?? true;
    app.notifAsked = prefs.getBool(_kNotifAsked) ?? false;

    app.coins = prefs.getInt(_kCoins) ?? 0;
    app._progressAt = prefs.getInt(_kProgressAt) ?? 0;
    app.tutorialDone = prefs.getBool(_kTutorialDone) ?? false;
    app._loginLastDay = prefs.getInt(_kLoginDay);
    app._loginStreakDay = prefs.getInt(_kLoginStreak) ?? 0;
    app._spinDay = prefs.getInt(_kSpinDay);
    app._spinsUsed = prefs.getInt(_kSpinsUsed) ?? 0;
    app._adSpinsUsed = prefs.getInt(_kAdSpinsUsed) ?? 0;
    app.levelStars.clear();
    for (final e in prefs.getStringList(_kLevelStars) ?? const <String>[]) {
      final parts = e.split(':');
      if (parts.length == 2) {
        app.levelStars[int.parse(parts[0])] = int.parse(parts[1]);
      }
    }
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
      _saveCoins();
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
      _saveCoins();
    }
    skin = s;
    BlockArt.style = s.style;
    _prefs.setString(_kSkin, s.id);
    notifyListeners();
    return true;
  }

  void addCoins(int amount) {
    if (amount == 0) return;
    coins += amount;
    _saveCoins();
    notifyListeners();
  }

  void setTutorialDone() {
    tutorialDone = true;
    _prefs.setBool(_kTutorialDone, true);
    notifyListeners();
  }

  // ------------------------------------------------------------- rewards

  /// Overridable clock so tests can move through days.
  DateTime Function() clock = DateTime.now;
  int get _today => LoginCalendar.dayNumber(clock());

  bool get loginRewardReady =>
      LoginCalendar.canClaim(lastClaimDay: _loginLastDay, today: _today);

  /// The calendar day (1..7) that is (or would be) claimed today.
  int get loginStreakDay => LoginCalendar.nextStreakDay(
        lastClaimDay: _loginLastDay,
        lastStreakDay: _loginStreakDay,
        today: _today,
      );

  void _saveCoins() {
    _prefs.setInt(_kCoins, coins);
    _touchWallet();
  }

  void _touchWallet() {
    _progressAt = DateTime.now().millisecondsSinceEpoch;
    _prefs.setInt(_kProgressAt, _progressAt);
  }

  /// Every saved change also queues a (debounced) cloud sync — except
  /// while a cloud merge is being applied, which would loop.
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_applying) cloud.schedule();
  }

  // ------------------------------------------------------------ cloud save

  @override
  ProgressSnapshot snapshot() {
    final t = AchievementTracker.instance;
    return ProgressSnapshot(
      savedAt: _progressAt,
      coins: coins,
      powerUps: {for (final e in powerUps.entries) e.key.name: e.value},
      bestClassic: bestClassic,
      levelStars: Map.of(levelStars),
      ownedThemes: Set.of(_ownedThemes),
      ownedSkins: Set.of(_ownedSkins),
      adsRemoved: adsRemoved,
      tutorialDone: tutorialDone,
      theme: theme.name,
      skin: skin.id,
      achievements: Set.of(t.unlocked),
      counters: Map.of(t.counters),
      totalLines: t.totalLinesCleared,
      gamesPlayed: t.gamesPlayed,
    );
  }

  @override
  void apply(ProgressSnapshot s) {
    _applying = true;
    try {
      coins = s.coins;
      _progressAt = s.savedAt;
      _prefs.setInt(_kCoins, coins);
      _prefs.setInt(_kProgressAt, _progressAt);
      for (final p in PowerUp.values) {
        final n = s.powerUps[p.name];
        if (n == null) continue;
        powerUps[p] = n;
        _prefs.setInt('$_kPowerUpPrefix${p.name}', n);
      }
      if (s.bestClassic > bestClassic) {
        bestClassic = s.bestClassic;
        _prefs.setInt(_kBestClassic, bestClassic);
      }
      levelStars
        ..clear()
        ..addAll(s.levelStars);
      _prefs.setStringList(
          _kLevelStars, [for (final e in levelStars.entries) '${e.key}:${e.value}']);
      _ownedThemes = Set.of(s.ownedThemes);
      _ownedSkins = Set.of(s.ownedSkins);
      _prefs.setStringList(_kOwnedThemes, _ownedThemes.toList());
      _prefs.setStringList(_kOwnedSkins, _ownedSkins.toList());
      if (s.adsRemoved && !adsRemoved) setAdsRemoved();
      if (s.tutorialDone && !tutorialDone) setTutorialDone();
      final th = AppTheme.byName(s.theme);
      if (th.name == s.theme && ownsTheme(th)) {
        theme = th;
        _prefs.setString(_kTheme, th.name);
      }
      final sk = Skins.byId(s.skin);
      if (sk.id == s.skin && ownsSkin(sk)) {
        skin = sk;
        BlockArt.style = sk.style;
        _prefs.setString(_kSkin, sk.id);
      }
      AchievementTracker.instance.restore(
        unlocked: s.achievements,
        counters: s.counters,
        totalLines: s.totalLines,
        gamesPlayed: s.gamesPlayed,
      );
      notifyListeners();
    } finally {
      _applying = false;
    }
  }

  // -------------------------------------------------------- achievements

  /// Called for every achievement as it unlocks (the app shows a banner
  /// and forwards it to Play Games).
  void Function(AchievementDef a)? onAchievementUnlocked;

  /// Unlocks anything the latest stats satisfy and pays its coins.
  void _checkAchievements() {
    final newly = AchievementTracker.instance
        .evaluate(bestClassic: bestClassic, coins: coins);
    _payAchievements(newly);
  }

  void _payAchievements(List<AchievementDef> newly) {
    if (newly.isEmpty) return;
    for (final a in newly) {
      coins += a.coinReward;
      onAchievementUnlocked?.call(a);
    }
    _saveCoins();
    notifyListeners();
  }

  /// Every placement during play: tracks combos, big clears, all-clears.
  void reportMove(PlacementResult r) {
    if (!r.cleared) return;
    final t = AchievementTracker.instance;
    t.raise(Counter.maxCombo, r.comboAfter);
    if (r.linesCleared >= 3) t.bump(Counter.bigClears);
    if (r.allClear) t.bump(Counter.allClears);
    Missions.instance.reportEvent(MissionMetric.comboReached, r.comboAfter);
    _checkAchievements();
  }

  /// Claims today's login reward. Returns it, or null if already claimed.
  Reward? claimLoginReward() {
    if (!loginRewardReady) return null;
    final day = loginStreakDay;
    final reward = LoginCalendar.days[day - 1];
    _loginLastDay = _today;
    _loginStreakDay = day;
    _prefs.setInt(_kLoginDay, _today);
    _prefs.setInt(_kLoginStreak, day);
    grant(reward);
    if (day == LoginCalendar.days.length) {
      AchievementTracker.instance.bump(Counter.loginWeeks);
      _checkAchievements();
    }
    return reward;
  }

  void _rollSpinDay() {
    if (_spinDay != _today) {
      _spinDay = _today;
      _spinsUsed = 0;
      _adSpinsUsed = 0;
      _prefs.setInt(_kSpinDay, _today);
      _prefs.setInt(_kSpinsUsed, 0);
      _prefs.setInt(_kAdSpinsUsed, 0);
    }
  }

  bool get freeSpinReady {
    _rollSpinDay();
    return _spinsUsed < LuckyWheel.freeSpinsPerDay;
  }

  int get adSpinsLeft {
    _rollSpinDay();
    return LuckyWheel.adSpinsPerDay - _adSpinsUsed;
  }

  /// Records a spin ([viaAd] for the extra ones) and grants the prize.
  void recordSpin(Reward prize, {required bool viaAd}) {
    _rollSpinDay();
    if (viaAd) {
      _adSpinsUsed++;
      _prefs.setInt(_kAdSpinsUsed, _adSpinsUsed);
    } else {
      _spinsUsed++;
      _prefs.setInt(_kSpinsUsed, _spinsUsed);
    }
    grant(prize);
    AchievementTracker.instance.bump(Counter.spins);
    _checkAchievements();
  }

  /// Adds a reward's coins and power-ups.
  void grant(Reward r) {
    if (r.coins > 0) {
      coins += r.coins;
      _saveCoins();
    }
    for (final e in r.items.entries) {
      powerUps[e.key] = powerUpCount(e.key) + e.value;
      _prefs.setInt('$_kPowerUpPrefix${e.key.name}', powerUps[e.key]!);
    }
    _touchWallet();
    notifyListeners();
  }

  /// Highest Adventure level the player may start.
  int get unlockedLevel {
    var n = 1;
    while (levelStars.containsKey(n) && n < Levels.count) {
      n++;
    }
    return n;
  }

  int get totalStars => levelStars.values.fold(0, (a, b) => a + b);

  /// Records a won level and pays out: first-clear coins plus coins for
  /// each star better than the previous best. Returns the coins awarded.
  int completeLevel(Level level, int stars) {
    final before = levelStars[level.number];
    var coinsEarned = 0;
    if (before == null) coinsEarned += level.firstClearCoins;
    final gained = stars - (before ?? 0);
    if (gained > 0) {
      coinsEarned += gained * Level.coinsPerStar;
      levelStars[level.number] = stars;
      _prefs.setStringList(
          _kLevelStars, [for (final e in levelStars.entries) '${e.key}:${e.value}']);
    }
    coins += coinsEarned;
    _saveCoins();
    final t = AchievementTracker.instance;
    if (before == null) {
      t.bump(Counter.levelsWon);
      Missions.instance.reportEvent(MissionMetric.levelsWon);
    }
    t.raise(Counter.stars, totalStars);
    notifyListeners();
    _checkAchievements();
    return coinsEarned;
  }

  int powerUpCount(PowerUp p) => powerUps[p] ?? 0;

  void addPowerUp(PowerUp p, [int n = 1]) {
    powerUps[p] = powerUpCount(p) + n;
    _prefs.setInt('$_kPowerUpPrefix${p.name}', powerUps[p]!);
    _touchWallet();
    notifyListeners();
  }

  /// Spends one [p] if the player has any. Returns whether it was used.
  bool usePowerUp(PowerUp p) {
    if (powerUpCount(p) <= 0) return false;
    addPowerUp(p, -1);
    AchievementTracker.instance.bump(Counter.powerUpsUsed);
    Missions.instance.reportEvent(MissionMetric.powerUpsUsed);
    _checkAchievements();
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
    _saveCoins();
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
      AchievementTracker.instance.bump(Counter.dailyPlayed);
      Missions.instance.reportEvent(MissionMetric.dailyPlayed);
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
      onAchievementUnlocked?.call(a);
    }

    coins += coinsEarned;
    _saveCoins();
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

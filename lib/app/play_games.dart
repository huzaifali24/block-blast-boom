import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'achievements.dart' show AchievementTracker;
import 'ads.dart';
import 'app_state.dart';

/// Google Play Games: sign-in and leaderboards for the two scores that
/// matter — best Classic run and best Daily Challenge run.
///
/// Players are signed in automatically by Google when the game opens (if
/// they have Play Games); otherwise they can sign in from the Me tab. There
/// is no cloud save yet (progress lives in local `shared_preferences` only,
/// see `app_state.dart`) — a reasonable next step once this is a real
/// publish, using the standard games_services flow.
class PlayGames extends ChangeNotifier {
  PlayGames._();
  static final instance = PlayGames._();

  // Leaderboard IDs come from secrets.json (see secrets.example.json).
  // Empty = that leaderboard is skipped (builds without the file still run).
  static const leaderboardClassic = String.fromEnvironment('PGS_LB_CLASSIC');
  static const leaderboardDaily = String.fromEnvironment('PGS_LB_DAILY');
  static const leaderboardStars = String.fromEnvironment('PGS_LB_STARS');

  /// Whether this build has leaderboard IDs at all (release builds made
  /// with `--dart-define-from-file=secrets.json`).
  static bool get configured => leaderboardClassic.isNotEmpty;

  /// Game achievement id (see `achievements.dart`) -> Play Games achievement
  /// id. Filled in once the achievements exist in Play Console; until then
  /// nothing is sent.
  static const achievementIds = <String, String>{
    'first_clear': String.fromEnvironment('PGS_ACH_FIRST_CLEAR'),
    'score_500': String.fromEnvironment('PGS_ACH_SCORE_500'),
    'score_1500': String.fromEnvironment('PGS_ACH_SCORE_1500'),
    'score_3000': String.fromEnvironment('PGS_ACH_SCORE_3000'),
    'lines_50': String.fromEnvironment('PGS_ACH_LINES_50'),
    'lines_250': String.fromEnvironment('PGS_ACH_LINES_250'),
    'lines_1000': String.fromEnvironment('PGS_ACH_LINES_1000'),
    'games_10': String.fromEnvironment('PGS_ACH_GAMES_10'),
    'games_100': String.fromEnvironment('PGS_ACH_GAMES_100'),
    'coins_1000': String.fromEnvironment('PGS_ACH_COINS_1000'),
    'combo_3': String.fromEnvironment('PGS_ACH_COMBO_3'),
    'combo_6': String.fromEnvironment('PGS_ACH_COMBO_6'),
    'big_clear': String.fromEnvironment('PGS_ACH_BIG_CLEAR'),
    'all_clear': String.fromEnvironment('PGS_ACH_ALL_CLEAR'),
    'all_clear_10': String.fromEnvironment('PGS_ACH_ALL_CLEAR_10'),
    'level_1': String.fromEnvironment('PGS_ACH_LEVEL_1'),
    'level_10': String.fromEnvironment('PGS_ACH_LEVEL_10'),
    'level_30': String.fromEnvironment('PGS_ACH_LEVEL_30'),
    'stars_45': String.fromEnvironment('PGS_ACH_STARS_45'),
    'stars_90': String.fromEnvironment('PGS_ACH_STARS_90'),
    'powerups_10': String.fromEnvironment('PGS_ACH_POWERUPS_10'),
    'spins_10': String.fromEnvironment('PGS_ACH_SPINS_10'),
    'daily_7': String.fromEnvironment('PGS_ACH_DAILY_7'),
    'login_7': String.fromEnvironment('PGS_ACH_LOGIN_7'),
  };

  bool signedIn = false;
  String? playerName;
  bool busy = false;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks Google's automatic sign-in from when the game opened.
  Future<void> init() async {
    if (!supported) return;
    try {
      final ok = await GameAuth.isSignedIn
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (ok) await _afterSignIn();
    } catch (e) {
      debugPrint('Play Games unavailable: $e');
    }
  }

  /// Sign-in from the button (shows Google's sign-in screen).
  Future<bool> signIn() async {
    if (!supported || busy) return signedIn;
    busy = true;
    notifyListeners();
    try {
      await GameAuth.signIn();
      await _afterSignIn();
    } catch (e) {
      debugPrint('Play Games sign-in failed: $e');
    }
    busy = false;
    notifyListeners();
    return signedIn;
  }

  Future<void> _afterSignIn() async {
    signedIn = true;
    try {
      playerName = await Player.getPlayerName();
    } catch (_) {}
    notifyListeners();
    // Pull this player's cloud save and merge it in (new phone, reinstall).
    await AppState.instance.cloud.sync();
    if (AppState.instance.adsRemoved) Ads.instance.removeAds();
    await submitAll();
    // Achievements earned before signing in (or on another phone).
    for (final id in AchievementTracker.instance.unlocked) {
      await _unlock(id);
    }
  }

  /// Sends a newly unlocked achievement to Play Games (no-op until the
  /// IDs are configured and the player is signed in).
  Future<void> unlock(String id) => _unlock(id);

  Future<void> _unlock(String id) async {
    final gid = achievementIds[id];
    if (!signedIn || gid == null || gid.isEmpty) return;
    try {
      await Achievements.unlock(
          achievement: Achievement(androidID: gid, percentComplete: 100));
    } catch (e) {
      debugPrint('Achievement not sent: $e');
    }
  }

  /// Opens Google's leaderboard screens (signing in first if needed).
  Future<void> showLeaderboards() async {
    if (!signedIn && !await signIn()) return;
    try {
      await Leaderboards.showLeaderboards();
    } catch (e) {
      debugPrint('Could not show leaderboards: $e');
    }
  }

  Future<void> submitAll() async {
    final app = AppState.instance;
    await _submit(leaderboardClassic, app.bestClassic);
    await _submit(leaderboardStars, app.totalStars);
  }

  /// Adventure: total stars earned across all levels.
  void starsChanged(int totalStars) {
    if (!signedIn) return;
    _submit(leaderboardStars, totalStars);
  }

  /// A finished game: submits to Classic or Daily depending on [isDaily].
  void gameDone({required bool isDaily, required int score}) {
    if (!signedIn) return;
    _submit(isDaily ? leaderboardDaily : leaderboardClassic, score);
  }

  Future<void> _submit(String id, int value) async {
    if (!signedIn || value <= 0 || id.isEmpty) return;
    try {
      await Leaderboards.submitScore(
          score: Score(androidLeaderboardID: id, value: value));
    } catch (e) {
      debugPrint('Score not sent: $e');
    }
  }
}

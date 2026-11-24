import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'achievements.dart' show AchievementTracker;
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

  /// Game achievement id (see `achievements.dart`) -> Play Games achievement
  /// id. Filled in once the achievements exist in Play Console; until then
  /// nothing is sent.
  static const achievementIds = <String, String>{};

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
    await submitAll();
    // Achievements earned before signing in (or on another phone).
    for (final id in AchievementTracker.instance.unlocked) {
      await _unlock(id);
    }
  }

  Future<void> _unlock(String id) async {
    final gid = achievementIds[id];
    if (!signedIn || gid == null) return;
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

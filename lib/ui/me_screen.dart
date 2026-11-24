import 'package:flutter/material.dart';

import '../app/achievements.dart';
import '../app/ads.dart';
import '../app/app_state.dart';
import '../app/missions.dart';
import '../app/play_games.dart';
import '../app/store.dart';
import '../app/theme.dart';
import '../game/game_screen.dart';
import '../game/modes.dart';
import 'widgets.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final t = app.theme;

    return ListenableBuilder(
      listenable:
          Listenable.merge([app, Ads.instance, Store.instance, PlayGames.instance]),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Profile'),
            const SizedBox(height: 20),

            _PlayGamesCard(theme: t),
            const SizedBox(height: 16),

            SectionLabel('Stats', theme: t),
            SectionCard(
              theme: t,
              child: Row(
                children: [
                  _Stat(theme: t, label: 'Best classic', value: '${app.bestClassic}'),
                  _Stat(
                      theme: t,
                      label: 'Lines cleared',
                      value: '${AchievementTracker.instance.totalLinesCleared}'),
                  _Stat(
                      theme: t,
                      label: 'Games played',
                      value: '${AchievementTracker.instance.gamesPlayed}'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SectionLabel('Daily missions', theme: t),
            for (final m in Missions.instance.today)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissionTile(theme: t, mission: m),
              ),
            const SizedBox(height: 14),

            SectionLabel('Achievements', theme: t),
            for (final a in AchievementTracker.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AchievementTile(
                    theme: t, achievement: a,
                    unlocked: AchievementTracker.instance.isUnlocked(a)),
              ),
            const SizedBox(height: 14),

            SectionLabel('Settings', theme: t),
            SectionCard(
              theme: t,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SwitchRow(
                    theme: t,
                    label: 'Music',
                    value: app.musicOn,
                    onChanged: app.setMusicOn,
                  ),
                  Divider(height: 1, color: t.line),
                  _SwitchRow(
                    theme: t,
                    label: 'Sound',
                    value: app.soundOn,
                    onChanged: app.setSoundOn,
                  ),
                  Divider(height: 1, color: t.line),
                  _SwitchRow(
                    theme: t,
                    label: 'Haptics',
                    value: app.hapticsOn,
                    onChanged: app.setHapticsOn,
                  ),
                  Divider(height: 1, color: t.line),
                  _SwitchRow(
                    theme: t,
                    label: 'Daily reminders',
                    value: app.remindersOn,
                    onChanged: app.setRemindersOn,
                  ),
                  Divider(height: 1, color: t.line),
                  ListTile(
                    title: Text('How to play', style: t.body(15, color: t.text)),
                    trailing: Icon(Icons.school_rounded, color: t.subtext),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          const GameScreen(mode: GameMode.classic, tutorial: true),
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (Ads.instance.privacyOptionsRequired)
              TextButton(
                onPressed: Ads.instance.showPrivacyOptions,
                child: const Text('Privacy preferences'),
              ),
            if (!app.adsRemoved)
              TextButton(
                onPressed: Store.instance.busy ? null : Store.instance.restore,
                child: const Text('Restore purchases'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayGamesCard extends StatelessWidget {
  const _PlayGamesCard({required this.theme});
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final pg = PlayGames.instance;
    if (!pg.supported) return const SizedBox.shrink();
    return SectionCard(
      theme: theme,
      child: Row(
        children: [
          Icon(Icons.leaderboard_rounded, color: theme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pg.signedIn
                  ? 'Signed in${pg.playerName != null ? ' as ${pg.playerName}' : ''}'
                  : 'Sign in to Google Play Games for leaderboards',
              style: theme.body(13, color: theme.text),
            ),
          ),
          if (pg.signedIn)
            TextButton(
                onPressed: pg.showLeaderboards, child: const Text('Rankings'))
          else
            TextButton(
                onPressed: pg.busy ? null : pg.signIn,
                child: const Text('Sign in')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.theme, required this.label, required this.value});
  final AppTheme theme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.title(20)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.body(11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.theme, required this.mission});
  final AppTheme theme;
  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final progress = Missions.instance.progressOf(mission);
    final complete = Missions.instance.isComplete(mission);
    final claimed = Missions.instance.isClaimed(mission);
    return SectionCard(
      theme: theme,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mission.title, style: theme.title(14)),
                const SizedBox(height: 6),
                ProgressBar(
                  value: progress / mission.target,
                  theme: theme,
                  color: claimed ? theme.subtext : theme.accent,
                ),
                const SizedBox(height: 4),
                Text('${progress.clamp(0, mission.target)}/${mission.target}',
                    style: theme.body(11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (claimed)
            Icon(Icons.check_circle_rounded, color: theme.subtext)
          else
            FilledButton(
              onPressed: complete
                  ? () => AppState.instance.claimMission(mission)
                  : null,
              style: FilledButton.styleFrom(backgroundColor: theme.gold),
              child: Text('+${mission.reward}'),
            ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.theme,
    required this.achievement,
    required this.unlocked,
  });

  final AppTheme theme;
  final AchievementDef achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      theme: theme,
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
            color: unlocked ? theme.gold : theme.subtext,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title,
                    style: theme.title(14,
                        color: unlocked ? theme.text : theme.subtext)),
                Text(achievement.description, style: theme.body(12)),
              ],
            ),
          ),
          if (!unlocked)
            Text('+${achievement.coinReward}',
                style: TextStyle(color: theme.gold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final AppTheme theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.body(14, color: theme.text))),
          Switch(value: value, onChanged: onChanged, activeTrackColor: theme.accent),
        ],
      ),
    );
  }
}

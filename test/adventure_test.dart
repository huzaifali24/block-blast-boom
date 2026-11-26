import 'package:block_boom/app/achievements.dart';
import 'package:block_boom/app/app_state.dart';
import 'package:block_boom/game/engine.dart';
import 'package:block_boom/game/game_screen.dart';
import 'package:block_boom/game/levels.dart';
import 'package:block_boom/game/modes.dart';
import 'package:block_boom/game/session.dart';
import 'package:block_boom/ui/adventure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'coins': 0});
    await AppState.load();
  });

  testWidgets('a level shows its goal and the starting board', (tester) async {
    phone(tester);
    final level = Levels.get(1);
    await tester.pumpWidget(MaterialApp(
        home: GameScreen(mode: GameMode.adventure, level: level)));
    await frames(tester);
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.textContaining(level.goal.describe(level.target)), findsOneWidget);
    final GameSession s = (tester.state(find.byType(GameScreen)) as dynamic).session;
    for (final e in level.prefilled.entries) {
      expect(s.board.cells[e.key], e.value);
    }
  });

  testWidgets('reaching the goal shows stars, pays coins and unlocks the next level',
      (tester) async {
    phone(tester);
    final level = Levels.get(1);
    await tester.pumpWidget(MaterialApp(
        home: GameScreen(mode: GameMode.adventure, level: level)));
    await frames(tester);
    final state = tester.state(find.byType(GameScreen)) as dynamic;
    final GameSession s = state.session;
    s.score = level.target;
    s.movesPlayed = level.par; // 3 stars
    expect(state.checkLevelWon(), isTrue);
    await frames(tester, 14);

    expect(find.text('Complete!'), findsWidgets);
    expect(find.text('Next Level'), findsOneWidget);
    expect(AppState.instance.levelStars[1], 3);
    expect(AppState.instance.unlockedLevel, 2);
    expect(AppState.instance.coins,
        level.firstClearCoins + 3 * Level.coinsPerStar + achievementCoins());
    await frames(tester, 40);
  });

  testWidgets('running out of space fails the level without touching bests',
      (tester) async {
    phone(tester);
    final level = Levels.get(2);
    await tester.pumpWidget(MaterialApp(
        home: GameScreen(mode: GameMode.adventure, level: level)));
    await frames(tester);
    final state = tester.state(find.byType(GameScreen)) as dynamic;
    final GameSession s = state.session;
    for (var i = 0; i < 64; i++) {
      s.board.cells[i] = i == 0 ? -1 : i % 7;
    }
    s.tray = <PieceShape?>[
      for (var k = 0; k < 3; k++)
        PieceShape('o', const [Cell(0, 0), Cell(1, 0), Cell(0, 1), Cell(1, 1)],
            PieceColor.amber),
    ];
    s.gameOver = true;
    state.triggerGameOver();
    await frames(tester, 16);
    await tester.tap(find.text('No thanks'));
    await frames(tester, 10);

    expect(find.text('Level Failed'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
    expect(AppState.instance.bestClassic, 0);
    expect(AppState.instance.levelStars, isEmpty);
    await frames(tester, 20);
  });

  testWidgets('the map locks levels ahead and opens unlocked ones', (tester) async {
    phone(tester);
    AppState.instance.completeLevel(Levels.get(1), 2);
    await tester.pumpWidget(const MaterialApp(home: AdventureScreen()));
    await frames(tester);

    expect(find.text('2/${Levels.count * 3}'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);

    await tester.tap(find.text('2').first);
    await frames(tester, 4);
    final l2 = Levels.get(2);
    expect(find.text(l2.goal.describe(l2.target)), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}

/// Coins paid by achievements unlocked so far (they top up balances).
int achievementCoins() => AchievementTracker.all
    .where(AchievementTracker.instance.isUnlocked)
    .fold(0, (s, a) => s + a.coinReward);

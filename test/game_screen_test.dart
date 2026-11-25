import 'package:block_bloom/app/achievements.dart';
import 'package:block_bloom/app/app_state.dart';
import 'package:block_bloom/game/engine.dart';
import 'package:block_bloom/game/game_screen.dart';
import 'package:block_bloom/game/modes.dart';
import 'package:block_bloom/game/powerups.dart';
import 'package:block_bloom/game/session.dart';
import 'package:block_bloom/ui/fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Outlined titles draw their text twice (outline + fill), so check for
/// presence rather than an exact count.
Matcher get shown => findsWidgets;

Future<dynamic> openGame(WidgetTester tester,
    {GameMode mode = GameMode.classic}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: GameScreen(mode: mode)));
  await frames(tester);
  return tester.state(find.byType(GameScreen));
}

void fill(GameSession s, {Set<int> holes = const {}}) {
  for (var i = 0; i < s.board.cells.length; i++) {
    s.board.cells[i] = holes.contains(i) ? -1 : i % 7;
  }
}

/// Pieces that can't fit anywhere on a nearly full board.
final bigTray = <PieceShape?>[
  for (var k = 0; k < 3; k++)
    PieceShape(
        'sq',
        const [
          Cell(0, 0),
          Cell(1, 0),
          Cell(2, 0),
          Cell(0, 1),
          Cell(1, 1),
          Cell(2, 1),
          Cell(0, 2),
          Cell(1, 2),
          Cell(2, 2),
        ],
        PieceColor.amber),
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'coins': 500});
    await AppState.load();
  });

  testWidgets('classic shows four power-ups with the starter count',
      (tester) async {
    await openGame(tester);
    for (final p in PowerUp.values) {
      expect(AppState.instance.powerUpCount(p), PowerUp.starterCount);
    }
    expect(find.text('2'), findsNWidgets(4));
  });

  testWidgets('daily challenge has no power-ups', (tester) async {
    await openGame(tester, mode: GameMode.daily);
    expect(find.textContaining('no power-ups'), findsOneWidget);
  });

  testWidgets('undo with nothing to undo just explains, costs nothing',
      (tester) async {
    final state = await openGame(tester);
    state.setState(() {}); // ensure the bar is built
    await tester.tap(find.byIcon(PowerUp.undo.icon));
    await frames(tester, 3);
    expect(find.text('Nothing to undo yet'), findsOneWidget);
    expect(AppState.instance.powerUpCount(PowerUp.undo), 2);
  });

  testWidgets('shuffle spends one and deals a full new tray', (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    s.tray[0] = null;
    s.tray[1] = null;
    await tester.tap(find.byIcon(PowerUp.shuffle.icon));
    await frames(tester, 3);
    expect(AppState.instance.powerUpCount(PowerUp.shuffle), 1);
    expect(s.tray.every((p) => p != null), isTrue);
  });

  testWidgets('bomb arms, shows a hint, and blasts where the board is tapped',
      (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    fill(s, holes: {0});
    state.setState(() {});
    await frames(tester, 2);

    await tester.tap(find.byIcon(PowerUp.bomb.icon));
    await frames(tester, 3);
    expect(find.text('Tap the board to blast'), findsOneWidget);

    // Tap the middle of the board.
    final grid = tester.getRect(find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == 'BoardPainter'));
    await tester.tapAt(grid.center);
    await frames(tester, 3);

    expect(AppState.instance.powerUpCount(PowerUp.bomb), 1);
    expect(s.board.isEmptyAt(3, 3), isTrue);
    expect(s.board.isEmptyAt(4, 4), isTrue);
    await frames(tester, 4); // hint fades out
    expect(find.text('Tap the board to blast'), findsNothing);
    await frames(tester, 15);
  });

  testWidgets(
      'a stuck board offers Revive; coins revive clears space and continues',
      (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    fill(s, holes: {0, 9});
    s.tray = List.of(bigTray);
    s.score = 420;
    s.gameOver = true;
    state.triggerGameOver();
    await frames(tester, 16);

    expect(find.text('Out of Space!'), shown);
    expect(find.text('Ad loading…'), findsOneWidget); // no ads in tests
    expect(find.text('or use a power-up'), findsOneWidget);

    await tester.tap(find.text('${ReviveRules.coinPrice}'));
    await frames(tester, 12);

    expect(AppState.instance.coins, 500 - ReviveRules.coinPrice);
    expect(find.text('Out of Space!'), findsNothing);
    expect(s.gameOver, isFalse);
    expect(s.score, 420);
    expect(s.tray.any((p) => p != null && s.board.canPlaceAnywhere(p)), isTrue);
    await frames(tester, 15);
  });

  testWidgets('declining Revive shows the results and records the game',
      (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    fill(s, holes: {0, 9});
    s.tray = List.of(bigTray);
    s.score = 77;
    s.gameOver = true;
    state.triggerGameOver();
    await frames(tester, 16);

    await tester.tap(find.text('No thanks'));
    await frames(tester, 10);
    expect(find.text('Play Again'), findsOneWidget);
    expect(AppState.instance.bestClassic, 77);
    await frames(tester, 30);
  });

  testWidgets('the Revive offer times out on its own', (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    fill(s, holes: {0, 9});
    s.tray = List.of(bigTray);
    s.gameOver = true;
    state.triggerGameOver();
    await frames(tester, 16);
    expect(find.text('Out of Space!'), shown);

    await frames(tester, ReviveRules.offerSeconds * 10 + 5);
    expect(find.text('Out of Space!'), findsNothing);
    expect(find.text('Play Again'), findsOneWidget);
    await frames(tester, 30);
  });

  testWidgets('using a rescue power-up from the offer resumes play',
      (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    fill(s, holes: {0, 9});
    s.tray = List.of(bigTray);
    s.gameOver = true;
    state.triggerGameOver();
    await frames(tester, 16);

    // The offer lists the owned Shuffle; tap it there (the last one found).
    await tester.tap(find.byIcon(PowerUp.shuffle.icon).last);
    await frames(tester, 6);
    expect(find.text('Out of Space!'), findsNothing);
    expect(AppState.instance.powerUpCount(PowerUp.shuffle), 1);
    await frames(tester, 20);
  });

  testWidgets('dragging a piece to finish a line on a 3-combo pays coins that fly in',
      (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    // Row 7 full except its first cell; a dot in tray slot 0.
    for (var i = 0; i < 64; i++) {
      s.board.cells[i] = -1;
    }
    for (var x = 1; x < 8; x++) {
      s.board.cells[7 * 8 + x] = 2;
    }
    s.board.cells[0] = 4; // a stray block, so this isn't an all-clear
    s.tray[0] = PieceShape('dot', const [Cell(0, 0)], PieceColor.mint);
    s.combo = 2;
    state.setState(() {});
    await frames(tester, 3);

    final grid = tester.getRect(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == 'BoardPainter'));
    final cell = grid.width / 8;
    final slot = tester.getRect(find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == 'PiecePainter' &&
        (w.painter as dynamic).shape.family == 'dot'));

    // The lifted piece floats ~0.9 cells above the finger, so aim the
    // finger just below the target cell.
    final target = grid.topLeft + Offset(cell / 2, 7 * cell + cell + cell * .9);
    final g = await tester.startGesture(slot.center);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(Offset.lerp(slot.center, target, .5)!);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(target);
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await frames(tester, 2);

    expect(s.board.isEmptyAt(1, 7), isTrue, reason: 'the line cleared');
    expect(s.combo, 3);
    final before = AppState.instance.coins;
    final achBefore = achievementCoins();
    expect(find.text('+${ComboRewards.coinsFor(PlacementResult(placedCells: 1, clearedRows: const [7], clearedCols: const [], clearedCells: const {}, clearedCellColors: const {}, points: 0, comboAfter: 3))}'), findsWidgets);
    await frames(tester, 12);
    // +5 combo coins, plus "Chain Reaction" for the first 3x combo (its
    // coins land the moment it unlocks, before this check's baseline).
    expect(AppState.instance.coins, before + 5);
    expect(achievementCoins(), greaterThanOrEqualTo(achBefore));
    await frames(tester, 30);
  });

  testWidgets('an all-clear throws confetti and pays the all-clear bonus',
      (tester) async {
    final state = await openGame(tester);
    final GameSession s = state.session;
    for (var i = 0; i < 64; i++) {
      s.board.cells[i] = -1;
    }
    for (var x = 1; x < 8; x++) {
      s.board.cells[7 * 8 + x] = 2;
    }
    s.tray[0] = PieceShape('dot', const [Cell(0, 0)], PieceColor.mint);
    state.setState(() {});
    await frames(tester, 3);
    final grid = tester.getRect(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == 'BoardPainter'));
    final cell = grid.width / 8;
    final slot = tester.getRect(find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == 'PiecePainter' &&
        (w.painter as dynamic).shape.family == 'dot'));
    final before = AppState.instance.coins;
    final achBefore = achievementCoins();
    final g = await tester.startGesture(slot.center);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(grid.topLeft + Offset(cell / 2, 8.9 * cell));
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await frames(tester, 3);

    expect(s.board.isEmpty, isTrue);
    expect(find.byType(Confetti), findsOneWidget);
    expect(find.text('All Clear!'), findsWidgets);
    await frames(tester, 12);
    expect(AppState.instance.coins,
        before + ComboRewards.allClear + achievementCoins() - achBefore);
    await frames(tester, 40);
  });
}

/// Coins paid by achievements unlocked so far (they top up balances).
int achievementCoins() => AchievementTracker.all
    .where(AchievementTracker.instance.isUnlocked)
    .fold(0, (s, a) => s + a.coinReward);

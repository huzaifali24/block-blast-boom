import 'package:block_boom/app/app_state.dart';
import 'package:block_boom/game/engine.dart';
import 'package:block_boom/game/game_screen.dart';
import 'package:block_boom/game/modes.dart';
import 'package:block_boom/game/session.dart';
import 'package:block_boom/game/tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> dragTo(WidgetTester tester, Cell target, PieceShape piece) async {
  final grid = tester.getRect(find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString() == 'BoardPainter'));
  final cell = grid.width / 8;
  final slot = tester.getRect(find.byWidgetPredicate((w) =>
      w is CustomPaint &&
      w.painter.runtimeType.toString() == 'PiecePainter' &&
      (w.painter as dynamic).shape == piece));
  final finger = grid.topLeft +
      Offset(target.x * cell + piece.width * cell / 2,
          target.y * cell + piece.height * cell + cell * .9);
  final g = await tester.startGesture(slot.center);
  await tester.pump(const Duration(milliseconds: 50));
  await g.moveTo(Offset.lerp(slot.center, finger, .5)!);
  await tester.pump(const Duration(milliseconds: 50));
  await g.moveTo(finger);
  await tester.pump(const Duration(milliseconds: 200));
  await g.up();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState.load();
    final s = GameScreen;
    expect(s, isNotNull);
  });

  test('every tutorial step is solvable: its piece fits the target and clears', () {
    for (final step in Tutorial.steps) {
      final b = Board(8);
      for (final i in step.filled) {
        b.cells[i] = 0;
      }
      expect(b.canPlace(step.piece, step.target.x, step.target.y), isTrue);
      final r = applyPlacement(
          board: b, shape: step.piece, ox: step.target.x, oy: step.target.y,
          colorIndex: 0, comboBefore: 0);
      expect(r.cleared, isTrue, reason: step.title);
    }
    expect(Tutorial.steps.last.filled, isNotEmpty);
  });

  testWidgets('playing through all three steps finishes the tutorial', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
        home: GameScreen(mode: GameMode.classic, tutorial: true)));
    await frames(tester);
    final state = tester.state(find.byType(GameScreen)) as dynamic;

    for (var i = 0; i < Tutorial.steps.length; i++) {
      final step = Tutorial.steps[i];
      expect(find.text(step.title), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);

      // A wrong spot is refused (the piece flies back).
      if (i == 0) {
        await dragTo(tester, const Cell(0, 0), step.piece);
        await frames(tester, 4);
        final GameSession s = state.session;
        expect(s.tray[1], isNotNull, reason: 'wrong spot must be refused');
      }

      await dragTo(tester, step.target, step.piece);
      await frames(tester, 2);
      await frames(tester, 12);
    }
    expect(AppState.instance.tutorialDone, isTrue);
    expect(find.text("You're ready!"), findsWidgets);
    final GameSession s = state.session;
    expect(s.tray.every((p) => p != null), isTrue, reason: 'a real game began');
    await frames(tester, 20);
  });

  testWidgets('Skip ends the tutorial straight away', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
        home: GameScreen(mode: GameMode.classic, tutorial: true)));
    await frames(tester);
    await tester.tap(find.text('Skip'));
    await frames(tester, 4);
    expect(AppState.instance.tutorialDone, isTrue);
    expect(find.text(Tutorial.steps.first.title), findsNothing);
    await frames(tester, 20);
  });
}

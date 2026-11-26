import 'package:block_boom/app/app_state.dart';
import 'package:block_boom/app/rewards.dart';
import 'package:block_boom/ui/main_shell.dart';
import 'package:block_boom/ui/rewards_ui.dart';
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
    AppState.instance.clock = DateTime.now;
  });

  testWidgets('the login calendar greets the player and pays out on CLAIM',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await frames(tester);
    expect(find.text('Daily Rewards'), findsWidgets);
    expect(find.text('DAY 1'), findsOneWidget);

    await tester.tap(find.text('CLAIM'));
    await frames(tester, 4);
    expect(AppState.instance.coins, LoginCalendar.days[0].coins);
    expect(AppState.instance.loginRewardReady, isFalse);

    await tester.tap(find.text('Awesome!'));
    await frames(tester, 4);
    expect(find.text('Daily Rewards'), findsNothing);
  });

  testWidgets('the free spin turns the wheel and awards its prize once a day',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showLuckyWheel(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await frames(tester, 4);
    expect(find.text('FREE SPIN'), findsOneWidget);

    final before = AppState.instance.coins;
    final items = AppState.instance.powerUps.values.fold(0, (a, b) => a + b);
    await tester.tap(find.text('FREE SPIN'));
    await frames(tester, 50); // the spin takes ~4s

    expect(find.textContaining('You won'), findsWidgets);
    expect(AppState.instance.freeSpinReady, isFalse);
    final after = AppState.instance.coins;
    final itemsAfter = AppState.instance.powerUps.values.fold(0, (a, b) => a + b);
    expect(after > before || itemsAfter > items, isTrue, reason: 'a prize was granted');
    expect(find.text('Ad loading…'), findsOneWidget); // no ads in tests
  });
}

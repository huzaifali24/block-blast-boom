import 'package:block_bloom/app/app_state.dart';
import 'package:block_bloom/app/play_games.dart';
import 'package:block_bloom/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState.load();
  });

  test('builds without secrets have no leaderboards configured', () {
    expect(PlayGames.configured, isFalse);
  });

  testWidgets('the leaderboard button explains instead of failing silently',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openLeaderboards(context),
            child: const Text('lb'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('lb'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Leaderboards go live'), findsOneWidget);
  });

  test('score submission is a safe no-op when not signed in', () {
    // Must not throw or call the plugin.
    PlayGames.instance.gameDone(isDaily: false, score: 999);
    PlayGames.instance.starsChanged(12);
  });
}

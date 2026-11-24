import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/ads.dart';
import 'app/app_state.dart';
import 'app/play_games.dart';
import 'app/reminders.dart';
import 'app/sound.dart';
import 'app/store.dart';
import 'app/theme.dart';
import 'ui/kodex_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppState.load();
  Ads.instance.adsRemoved = AppState.instance.adsRemoved;
  await Sound.instance.init();
  runApp(const BlockBloomApp());
  // After the first frame, so the consent form has a screen to appear over.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Ads.instance.init();
    Store.instance.init();
    Reminders.instance.init();
    PlayGames.instance.init();
  });
}

class BlockBloomApp extends StatelessWidget {
  const BlockBloomApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final t = AppState.instance.theme;
          return MaterialApp(
            title: 'Block Bloom',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: kFont,
              brightness: t.dark ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: t.background,
              colorScheme: ColorScheme.fromSeed(
                seedColor: t.accent,
                brightness: t.dark ? Brightness.dark : Brightness.light,
              ),
            ),
            home: const KodexSplash(),
          );
        },
      );
}

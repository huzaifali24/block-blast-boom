import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/ads.dart';
import 'app/app_state.dart';
import 'app/music.dart';
import 'app/play_games.dart';
import 'app/reminders.dart';
import 'app/sound.dart';
import 'app/store.dart';
import 'app/theme.dart';
import 'l10n/l10n.dart';
import 'ui/achievement_banner.dart';
import 'ui/kodex_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppState.load();
  AppState.instance.onAchievementUnlocked = (a) {
    AchievementToasts.show(a);
    Sound.instance.play(SoundEffect.coin);
    PlayGames.instance.unlock(a.id);
  };
  Ads.instance.adsRemoved = AppState.instance.adsRemoved;
  await Sound.instance.init();
  runApp(const BlockBoomApp());
  // Not awaited: the loop renders on a background isolate the first time.
  Music.instance.init(enabled: AppState.instance.musicOn);
  // After the first frame, so the consent form has a screen to appear over.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Ads.instance.init();
    Store.instance.init();
    Reminders.instance.init();
    PlayGames.instance.init();
  });
}

class BlockBoomApp extends StatelessWidget {
  const BlockBoomApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final t = AppState.instance.theme;
          final device = WidgetsBinding.instance.platformDispatcher.locale;
          L10n.code = L10n.resolve(AppState.instance.language, device);
          return MaterialApp(
            title: 'Block Boom',
            locale: Locale(L10n.code),
            supportedLocales: L10n.supported,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            debugShowCheckedModeBanner: false,
            builder: (context, child) =>
                AchievementBannerHost(child: child ?? const SizedBox()),
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: kFont,
              // Urdu letters aren't in Poppins; fall back to Nastaliq.
              fontFamilyFallback: const [L10n.urduFont],
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

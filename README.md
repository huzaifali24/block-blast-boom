# Block Bloom

A calm but endless wood-block puzzle for Android, built with Flutter.

Drag pieces onto an 8x8 board to fill rows and columns — clear a line and it
disappears, clear several at once and the combo keeps compounding. Play
Classic for an endless high-score chase, or Daily Challenge for one shared
board every player sees that day.

## Features

- Classic endless mode and a calendar-seeded Daily Challenge with streaks.
- 15 piece families (from a single dot up to a 3x3 block), drawn from a
  weighted bag with soft anti-repeat so the tray stays varied.
- Combo scoring: clearing several lines in one move, or several moves in a
  row, pays far more than clearing them one at a time.
- Four board themes and four block skins, unlockable with in-game coins.
- Daily missions, achievements, and optional Google Play Games
  leaderboards/achievements, local reminders, and AdMob ads.

## Build and run

Requirements: Flutter (stable) and the Android SDK.

```sh
flutter pub get
flutter run
```

That's all you need to play and develop. Without any configuration the app
shows Google's public **test** ads and runs without Play Games.

```sh
flutter test        # engine and gameplay tests
flutter analyze
```

## Your own IDs (optional, for publishing)

No account IDs or keys are kept in this repository. To publish your own
build, copy the example files and fill in your IDs:

| File (not committed) | Copy from | Holds |
|---|---|---|
| `secrets.json` | `secrets.example.json` | AdMob ad unit IDs, Play Games leaderboard/achievement IDs |
| `android/secrets.properties` | `android/secrets.example.properties` | AdMob app ID, Play Games project ID |
| `android/key.properties` + keystore | see [Flutter docs](https://docs.flutter.dev/deployment/android#sign-the-app) | Release signing key |

Then build:

```sh
flutter build appbundle --dart-define-from-file=secrets.json
```

## Project layout

```
lib/game/   board + scoring engine (engine.dart), piece shapes and bag,
            game session, board painter, game screen, modes
lib/app/    app state and progress, ads, store, Play Games, reminders,
            missions, achievements, sound, themes
lib/ui/     splash, shell, home, shop and profile screens
test/       unit tests
store/      Play Store listing text and graphics
privacy/    privacy policy page
```

## Contributing

Issues and pull requests are welcome. Please run `flutter analyze` and
`flutter test` before opening a pull request.

## License

[MIT](LICENSE). The code is free to use, change and share.

// Renders the Google Play listing art (feature graphic + phone screenshots,
// English and Urdu) from the real game screens.
//
// Run from the project root:
//   flutter test tool/store/generate_store_assets_test.dart
//
// Output: store/listing/<lang>/feature_graphic.png and screenshot_N.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:block_boom/app/app_state.dart';
import 'package:block_boom/app/theme.dart';
import 'package:block_boom/game/board_painter.dart';
import 'package:block_boom/game/engine.dart';
import 'package:block_boom/game/game_screen.dart';
import 'package:block_boom/game/levels.dart';
import 'package:block_boom/game/modes.dart';
import 'package:block_boom/game/powerups.dart';
import 'package:block_boom/game/skins.dart';
import 'package:block_boom/l10n/l10n.dart';
import 'package:block_boom/ui/adventure_screen.dart';
import 'package:block_boom/ui/fx.dart';
import 'package:block_boom/ui/home_screen.dart';
import 'package:block_boom/ui/rewards_ui.dart';
import 'package:block_boom/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _key = GlobalKey();

const _captions = {
  'en': [
    'Drag, drop & blast lines!',
    'Chain combos for huge scores',
    '30 Adventure levels',
    'Collect gems, earn stars',
    "Power-ups when you're stuck",
    'Daily rewards & lucky spins',
    'Glowing skins & themes',
  ],
  'ur': [
    'گھسیٹیں، رکھیں، لائنیں اُڑائیں!',
    'کومبو بنائیں، بڑا اسکور پائیں',
    'مہم کے 30 لیول',
    'جواہر جمع کریں، ستارے جیتیں',
    'مشکل میں پاور اپس',
    'روزانہ انعامات اور خوش قسمت چکر',
    'چمکدار اسکنز اور تھیمز',
  ],
};

const _tagline = {
  'en': 'Blast lines. Chain combos. BOOM!',
  'ur': 'لائنیں اُڑائیں، کومبو بنائیں!',
};

Future<void> _fonts() async {
  final poppins = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    poppins.addFont(rootBundle.load('assets/fonts/Poppins-$w.ttf'));
  }
  await poppins.load();
  await (FontLoader(L10n.urduFont)
        ..addFont(rootBundle.load('assets/fonts/NotoNastaliqUrdu.ttf')))
      .load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}

Future<void> _save(WidgetTester t, String path, double ratio) async {
  await t.runAsync(() async {
    final rb = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await rb.toImage(pixelRatio: ratio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _frames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(String lang, Widget home) => RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(lang),
        supportedLocales: L10n.supported,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
            fontFamily: kFont, fontFamilyFallback: const [L10n.urduFont]),
        home: home,
      ),
    );

/// A store screenshot: a big caption over the live screen in a phone frame.
Widget _shot(String caption, Widget screen) => Scaffold(
      body: AmbientBackground(
        theme: AppTheme.indigo,
        child: Column(
          children: [
            SizedBox(
              height: 150,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ArcadeText(caption, size: 34),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                  border: Border.all(color: const Color(0xFF0B0C2A), width: 6),
                  boxShadow: const [
                    BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  // Its own screen size and navigator, so layouts and
                  // pop-ups behave as on a phone this size.
                  child: LayoutBuilder(
                    builder: (context, c) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          size: c.biggest,
                          padding: EdgeInsets.zero,
                          viewPadding: EdgeInsets.zero),
                      child: Navigator(
                        // A fresh navigator per shot (it only builds its
                        // first route once).
                        key: ValueKey(caption),
                        onGenerateRoute: (_) =>
                            MaterialPageRoute<void>(builder: (_) => screen),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

void _fill(dynamic session, List<String> rows) {
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final ch = rows[y][x];
      session.board.cells[y * 8 + x] = ch == '.' ? -1 : (ch.codeUnitAt(0) - 65) % 7;
    }
  }
}

Future<TestGesture> _dragTo(WidgetTester t, PieceShape piece, Cell target) async {
  final grid = t.getRect(find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString() == 'BoardPainter'));
  final cell = grid.width / 8;
  final slot = t.getRect(find.byWidgetPredicate((w) =>
      w is CustomPaint &&
      w.painter.runtimeType.toString() == 'PiecePainter' &&
      (w.painter as dynamic).shape == piece));
  final finger = grid.topLeft +
      Offset(target.x * cell + piece.width * cell / 2,
          target.y * cell + piece.height * cell + cell * .9);
  final g = await t.startGesture(slot.center);
  await t.pump(const Duration(milliseconds: 60));
  await g.moveTo(Offset.lerp(slot.center, finger, .5)!);
  await t.pump(const Duration(milliseconds: 60));
  await g.moveTo(finger);
  await _frames(t, 3);
  return g;
}

void main() {
  testWidgets('store assets', (t) async {
    await t.runAsync(_fonts);
    // 360x640 logical at 3x = exactly 1080x1920 (9:16).
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;

    for (final lang in ['en', 'ur']) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({
        'coins': 1250,
        'tutorial_done': true,
        'login_last_day': 0,
        'best_classic': 4820,
      });
      await t.runAsync(AppState.load);
      final app = AppState.instance;
      app.clock = () => DateTime(2026, 12, 1, 10);
      for (var n = 1; n <= 7; n++) {
        app.completeLevel(Levels.get(n), n.isEven ? 2 : 3);
      }
      L10n.code = lang;
      final out = 'store/listing/$lang';
      final cap = _captions[lang]!;
      const ratio = 3.0;

      // 1 + 2: drag preview, then the combo burst after dropping.
      final domino = PieceShape('d', const [Cell(0, 0), Cell(0, 1)], PieceColor.cyan);
      await t.pumpWidget(_app(lang, _shot(cap[0],
          GameScreen(key: UniqueKey(), mode: GameMode.classic))));
      await _frames(t, 6);
      var st = t.state(find.byType(GameScreen)) as dynamic;
      _fill(st.session, const [
        '........',
        '..AA....',
        '.BBA..C.',
        'DDB..CC.',
        'DFEE.GF.',
        'GGEB.BAD',
        'ABCD.EFG',
        'FDCB.AGE',
      ]);
      st.session.score = 2360;
      st.session.combo = 1;
      st.session.tray = <PieceShape?>[
        PieceShape('t', const [Cell(0, 0), Cell(1, 0), Cell(2, 0), Cell(1, 1)], PieceColor.pink),
        domino,
        PieceShape('o', const [Cell(0, 0), Cell(1, 0), Cell(0, 1), Cell(1, 1)], PieceColor.mint),
      ];
      st.setState(() {});
      await _frames(t, 6);
      final g = await _dragTo(t, domino, const Cell(4, 6));
      await _save(t, '$out/screenshot_1.png', ratio);
      await g.up();
      await _frames(t, 30);

      // Same setup under the second caption, this time dropping the piece.
      await t.pumpWidget(_app(lang, _shot(cap[1],
          GameScreen(key: UniqueKey(), mode: GameMode.classic))));
      await _frames(t, 6);
      st = t.state(find.byType(GameScreen)) as dynamic;
      _fill(st.session, const [
        '........',
        '..AA....',
        '.BBA..C.',
        'DDB..CC.',
        'DFEE.GF.',
        'GGEB.BAD',
        'ABCD.EFG',
        'FDCB.AGE',
      ]);
      st.session.score = 2360;
      st.session.combo = 1;
      st.session.tray = <PieceShape?>[
        PieceShape('t', const [Cell(0, 0), Cell(1, 0), Cell(2, 0), Cell(1, 1)], PieceColor.pink),
        domino,
        PieceShape('o', const [Cell(0, 0), Cell(1, 0), Cell(0, 1), Cell(1, 1)], PieceColor.mint),
      ];
      st.setState(() {});
      await _frames(t, 6);
      final g2 = await _dragTo(t, domino, const Cell(4, 6));
      await g2.up();
      await t.pump(const Duration(milliseconds: 120));
      await t.pump(const Duration(milliseconds: 120));
      await t.pump(const Duration(milliseconds: 120));
      await _save(t, '$out/screenshot_2.png', ratio);
      await _frames(t, 40);

      // 3: Adventure map.
      await t.pumpWidget(_app(lang, _shot(cap[2], const AdventureScreen())));
      await _frames(t, 8);
      await _save(t, '$out/screenshot_3.png', ratio);

      // 4: a gem level.
      await t.pumpWidget(_app(lang, _shot(cap[3],
          GameScreen(key: UniqueKey(), mode: GameMode.adventure, level: Levels.get(9)))));
      await _frames(t, 8);
      await _save(t, '$out/screenshot_4.png', ratio);
      await _frames(t, 30);

      // 5: power-ups, Bomb armed.
      await t.pumpWidget(_app(lang, _shot(cap[4],
          GameScreen(key: UniqueKey(), mode: GameMode.classic))));
      await _frames(t, 6);
      st = t.state(find.byType(GameScreen)) as dynamic;
      _fill(st.session, const [
        '........',
        '...A....',
        '..BAC...',
        '.DBCCF..',
        'GDEECFA.',
        'GGEBBBAD',
        'ABC.DEFG',
        'FDCBBAGE',
      ]);
      st.session.score = 3140;
      st.setState(() {});
      await _frames(t, 4);
      await t.tap(find.byIcon(PowerUp.bomb.icon).last);
      await _frames(t, 6);
      await _save(t, '$out/screenshot_5.png', ratio);
      await t.tap(find.byIcon(PowerUp.bomb.icon).last);
      await _frames(t, 30);

      // 6: daily rewards over the home screen.
      await t.pumpWidget(_app(lang, _shot(cap[5], Scaffold(
        body: AmbientBackground(
          theme: AppTheme.indigo,
          child: const SafeArea(child: HomeScreen()),
        ),
      ))));
      await _frames(t, 6);
      showLuckyWheel(t.element(find.byType(HomeScreen)), useRootNavigator: false);
      await _frames(t, 6);
      await _save(t, '$out/screenshot_6.png', ratio);
      await t.tap(find.text(tr('Close')));
      await _frames(t, 6);

      // 7: Neon Glow skin on the Night theme.
      app.buyOrSelectSkin(Skins.neonGlow);
      app.buyOrSelectTheme(AppTheme.night);
      app.addCoins(5000);
      app.buyOrSelectSkin(Skins.neonGlow);
      app.buyOrSelectTheme(AppTheme.night);
      await t.pumpWidget(_app(lang, _shot(cap[6],
          GameScreen(key: UniqueKey(), mode: GameMode.classic))));
      await _frames(t, 6);
      st = t.state(find.byType(GameScreen)) as dynamic;
      _fill(st.session, const [
        '........',
        '.A......',
        '.AB..F..',
        'CDBB.FE.',
        'CDEGGGE.',
        'ADEFBCAD',
        'ABC.DEFG',
        'FDCBBA.E',
      ]);
      st.session.score = 5210;
      st.setState(() {});
      await _frames(t, 8);
      await _save(t, '$out/screenshot_7.png', ratio);
      await _frames(t, 30);
      BlockArt.style = BlockStyle.gloss;

      // Feature graphic, 1024x500.
      t.view.physicalSize = const Size(1024, 500);
      t.view.devicePixelRatio = 2;
      await t.pumpWidget(_app(lang, _FeatureGraphic(tagline: _tagline[lang]!)));
      await _frames(t, 6);
      await _save(t, '$out/feature_graphic.png', 2);
      t.view.physicalSize = const Size(1080, 1920);
      t.view.devicePixelRatio = 3;
      await _frames(t, 30);
    }
    L10n.code = 'en';
  });
}

class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic({required this.tagline});
  final String tagline;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AmbientBackground(
          theme: AppTheme.indigo,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                const SizedBox(width: 26),
                SizedBox(
                  width: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const LightRays(size: 250, color: Color(0xFF9FB0FF)),
                      CustomPaint(size: const Size(170, 120), painter: _Blocks()),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ArcadeText('BLOCK BOOM', size: 46),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ArcadeText(tagline,
                            size: 22,
                            colors: const [Colors.white, Color(0xFFCFD6FF)],
                            stroke: const Color(0xFF14154A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
              ],
            ),
          ),
        ),
      );
}

class _Blocks extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Skins.classic.colors;
    final cell = size.height / 2.6;
    const cells = [
      (0.0, 1.5, 3), (1.0, 1.5, 3), (1.0, .5, 3), (2.0, 1.5, 0),
      (2.0, .5, 1), (3.0, 1.5, 2), (3.0, .5, 6), (2.6, -.6, 5),
    ];
    final ox = (size.width - cell * 4) / 2;
    for (final (x, y, k) in cells) {
      BlockArt.block(canvas, Rect.fromLTWH(ox + x * cell, y * cell, cell, cell), c[k]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

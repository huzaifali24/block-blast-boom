import 'dart:ui' as ui;

import 'package:block_boom/app/app_state.dart';
import 'package:block_boom/app/theme.dart';
import 'package:block_boom/game/board_painter.dart';
import 'package:block_boom/game/skins.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every skin has a color per piece and a unique id', () {
    expect(Skins.all.map((s) => s.id).toSet(), hasLength(Skins.all.length));
    for (final s in Skins.all) {
      expect(s.colors, hasLength(7), reason: s.name);
    }
    expect(Skins.all.map((s) => s.style).toSet(), BlockStyle.values.toSet());
  });

  test('theme names are unique and the default is free', () {
    expect(AppTheme.all.map((t) => t.name).toSet(), hasLength(AppTheme.all.length));
    expect(AppTheme.all.first.price, 0);
  });

  test('every block material renders at several sizes', () {
    for (final style in BlockStyle.values) {
      for (final size in [12.0, 44.0, 120.0]) {
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        BlockArt.block(canvas, Rect.fromLTWH(0, 0, size, size),
            const Color(0xFF3FD16B), as: style);
        BlockArt.block(canvas, Rect.fromLTWH(0, 0, size, size),
            const Color(0xFF3FD16B), as: style, opacity: .4);
        rec.endRecording().dispose();
      }
    }
  });

  test('buying a styled skin switches the block material', () async {
    SharedPreferences.setMockInitialValues({'coins': 5000});
    await AppState.load();
    final app = AppState.instance;
    expect(BlockArt.style, BlockStyle.gloss);
    expect(app.buyOrSelectSkin(Skins.wood), isTrue);
    expect(BlockArt.style, BlockStyle.wood);
    expect(app.coins, 5000 - Skins.wood.priceCoins);
    expect(app.buyOrSelectSkin(Skins.classic), isTrue);
    expect(BlockArt.style, BlockStyle.gloss);
    // Re-selecting an owned skin is free.
    expect(app.buyOrSelectSkin(Skins.wood), isTrue);
    expect(app.coins, 5000 - Skins.wood.priceCoins);
  });
}

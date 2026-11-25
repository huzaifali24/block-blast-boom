import 'dart:io';

import 'package:block_bloom/app/achievements.dart';
import 'package:block_bloom/app/theme.dart';
import 'package:block_bloom/game/levels.dart';
import 'package:block_bloom/game/powerups.dart';
import 'package:block_bloom/game/skins.dart';
import 'package:block_bloom/game/tutorial.dart';
import 'package:block_bloom/l10n/l10n.dart';
import 'package:block_bloom/l10n/ur.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every `tr('...')` / `tr("...")` literal in lib/.
Set<String> trLiterals() {
  final re = RegExp(r'''\btr\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''');
  final out = <String>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart') || f.path.contains('l10n')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      out.add((m.group(1) ?? m.group(2)!).replaceAll(r"\'", "'"));
    }
  }
  return out;
}

/// Data strings translated where they're shown.
Set<String> dataStrings() => {
      for (final a in AchievementTracker.all) ...[a.title, a.description],
      for (final p in PowerUp.values) ...[p.label, p.hint],
      for (final s in Skins.all) s.name,
      for (final t in AppTheme.all) t.name,
      for (final s in Tutorial.steps) ...[s.title, s.text],
      for (final g in LevelGoal.values) g.label,
    };

Set<String> placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  test('every tr() string in the code has an Urdu translation', () {
    final literals = trLiterals();
    expect(literals.length, greaterThan(100), reason: 'scanner found the strings');
    final missing = literals.where((k) => !urdu_.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'missing Urdu for: $missing');
  });

  test('every achievement, mission, power-up, skin, theme and tutorial text is translated', () {
    // Missions and reminders are covered by the source scan of their files.
    final src = File('lib/app/missions.dart').readAsStringSync();
    final missionTitles = RegExp(r"title: '([^']*)'").allMatches(src).map((m) => m.group(1)!);
    final all = {...dataStrings(), ...missionTitles};
    final missing = all.where((k) => !urdu_.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'missing Urdu for: $missing');
  });

  test('translations keep exactly the same placeholders', () {
    for (final e in urdu_.entries) {
      expect(placeholders(e.value), placeholders(e.key), reason: e.key);
    }
  });

  test('tr() switches language and fills placeholders', () {
    L10n.code = 'en';
    expect(tr('Level {n}', {'n': 4}), 'Level 4');
    L10n.code = 'ur';
    expect(tr('Level {n}', {'n': 4}), 'لیول 4');
    expect(tr('Some text nobody translated'), 'Some text nobody translated');
    L10n.code = 'en';
  });

  test('language choice resolves sensibly', () {
    expect(L10n.resolve('system', const Locale('ur', 'PK')), 'ur');
    expect(L10n.resolve('system', const Locale('fr')), 'en');
    expect(L10n.resolve('en', const Locale('ur')), 'en');
    expect(L10n.resolve('ur', const Locale('en')), 'ur');
  });
}

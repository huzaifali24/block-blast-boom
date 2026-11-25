import 'package:flutter/widgets.dart';

import 'ur.dart';

/// Lightweight localization. UI strings are written in English and wrapped
/// in [tr]; each other language maps the English text to its translation.
/// A test (test/l10n_test.dart) scans the code and fails if any `tr(...)`
/// string is missing a translation, so nothing silently stays English.
class L10n {
  L10n._();

  static const english = Locale('en');
  static const urdu = Locale('ur');
  static const supported = [english, urdu];

  /// Font used for scripts Poppins can't draw.
  static const urduFont = 'NotoNastaliqUrdu';

  /// The language code currently in use.
  static String code = 'en';

  static bool get isRtl => code == 'ur';

  static const _tables = <String, Map<String, String>>{'ur': urdu_};

  /// Picks the language to use: an explicit choice ('en'/'ur'), or for
  /// 'system' the device language when supported, else English.
  static String resolve(String choice, Locale device) {
    if (choice != 'system') return choice;
    return supported.any((l) => l.languageCode == device.languageCode)
        ? device.languageCode
        : 'en';
  }

  static String translate(String en) => _tables[code]?[en] ?? en;
}

/// Translates [en] into the current language, filling `{name}`
/// placeholders from [args].
String tr(String en, [Map<String, Object> args = const {}]) {
  var s = L10n.translate(en);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

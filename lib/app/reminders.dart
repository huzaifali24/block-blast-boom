import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_state.dart';
import '../l10n/l10n.dart';

/// Daily reminder notifications: "today's board is ready", with a streak
/// nudge while one is going. Scheduled on the phone itself (no server): the
/// next [days] evenings are queued and refreshed whenever the app opens or
/// the daily challenge is played, so today's reminder is skipped once it's
/// already done.
class Reminders {
  Reminders._();
  static final instance = Reminders._();

  /// Local time of the reminder.
  static const hour = 19;
  static const days = 7;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android:
              AndroidInitializationSettings('@drawable/ic_stat_boom'),
        ),
      );
      _ready = true;
      await reschedule();
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  /// Asks for permission to show notifications (Android 13+). Asked once,
  /// after the player has had a taste of the game.
  Future<void> askPermissionOnce() async {
    final app = AppState.instance;
    if (!_ready || app.notifAsked) return;
    app.setNotifAsked();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await reschedule();
  }

  /// Rebuilds the queue of upcoming reminders from the current progress.
  Future<void> reschedule() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final app = AppState.instance;
      if (!app.remindersOn) return;
      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < days; i++) {
        final at =
            tz.TZDateTime(tz.local, now.year, now.month, now.day + i, hour);
        if (!at.isAfter(now)) continue;
        if (i == 0 && app.dailyDoneToday) continue;
        final (title, body) = _message(app, i);
        await _plugin.zonedSchedule(
          id: 100 + i,
          scheduledDate: at,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily',
              'Daily challenge',
              channelDescription:
                  'A reminder when a new daily board is ready',
              color: Color(0xFF6C74FF), // Block Boom indigo
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  static const _plain = [
    ("Today's board is ready 💥", 'A fresh 8x8 grid is waiting. Blast it!'),
    ('New daily challenge', 'Everyone plays the same board today. Beat it.'),
    ('Time for a quick game?', "Today's daily challenge is waiting."),
    ('Block Boom', 'Your daily puzzle is ready whenever you are.'),
  ];

  /// What to say [dayOffset] days from now.
  static (String, String) _message(AppState app, int dayOffset) {
    final streak = app.dailyStreak;
    final alive = streak > 0;
    final first = dayOffset == 0 || (dayOffset == 1 && app.dailyDoneToday);
    if (alive && first) {
      return (
        tr("Don't lose your {n}-day streak! 🔥", {'n': streak}),
        tr("Today's daily board is waiting. Keep it going."),
      );
    }
    final (title, body) =
        _plain[(DateTime.now().day + dayOffset) % _plain.length];
    return (tr(title), tr(body));
  }
}

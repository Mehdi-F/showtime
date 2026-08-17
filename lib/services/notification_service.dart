import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../config/constants.dart';
import '../screens/show_detail_screen.dart';
import '../widgets/app_page_route.dart';

/// Local (on-device) episode-reminder notifications — no backend involved.
/// One pending notification per show at most: scheduling again for the same
/// tmdbId replaces whatever was previously scheduled for it.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Fall back to UTC-based scheduling if the device timezone is unrecognized.
    }

    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final tmdbId = int.tryParse(response.payload ?? '');
    if (tmdbId == null) return;
    navigatorKey.currentState?.push(appRoute(builder: (_) => ShowDetailScreen.preview(tmdbId: tmdbId)));
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    // null means this Android version doesn't require the runtime prompt at all.
    return granted ?? true;
  }

  /// Schedules (or replaces) the reminder for [tmdbId], the evening before
  /// [episodeAirDate]. No-ops if that reminder time has already passed.
  Future<void> scheduleShowReminder({
    required int tmdbId,
    required String showName,
    required DateTime episodeAirDate,
  }) async {
    final dayBefore = episodeAirDate.subtract(const Duration(days: 1));
    final reminderAt = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, AppConstants.episodeReminderHour);
    final scheduled = tz.TZDateTime.from(reminderAt, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      tmdbId,
      showName,
      'Nouvel épisode demain !',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'episode_reminders',
          'Rappels d\'épisodes',
          channelDescription: 'Rappel la veille de la sortie d\'un nouvel épisode',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: tmdbId.toString(),
    );
  }

  Future<void> cancelShowReminder(int tmdbId) => _plugin.cancel(tmdbId);
}

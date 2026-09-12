import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and cancels the due-date reminders for Objective 3.
///
/// One instance owns the plugin for the whole app. A reminder is
/// identified by the debt's own row id, so a debt can only ever have one
/// pending reminder and cancelling does not need a lookup table.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  static const String _channelId = 'debt_reminders';
  static const String _channelName = 'Debt reminders';
  static const String _channelDescription =
      'Reminders for money you owe or are owed';

  /// Sets up the timezone database and the notification channel. Must be
  /// awaited before anything is scheduled, so it is called from main().
  Future<void> init() async {
    if (_initialised) return;

    // Scheduled notifications are tied to a wall-clock time in a specific
    // zone. Without this the plugin has no zone to resolve against and
    // zonedSchedule throws.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    _initialised = true;
  }

  /// The Android side of the plugin, or null on any other platform.
  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asks for the Android 13+ notification permission. Returns false if
  /// the user declines, so a caller can decide whether to explain why the
  /// reminder will not appear.
  Future<bool> requestPermission() async {
    await init();
    final android = _android;
    if (android == null) return false;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Schedules a reminder for 9am on [dueDate].
  ///
  /// A date already in the past is skipped rather than scheduled, since
  /// the plugin would otherwise fire it immediately, which is confusing
  /// when the user is only editing an old record.
  Future<void> scheduleDebtReminder({
    required int id,
    required String personName,
    required int amountCents,
    required DateTime dueDate,
    required bool iOwe,
  }) async {
    await init();
    await cancelDebtReminder(id);

    final when = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
    );

    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    final amount = 'RM ${(amountCents / 100).toStringAsFixed(2)}';
    final title = iOwe ? 'Payment due today' : 'Collection due today';
    final body = iOwe
        ? 'You owe $personName $amount'
        : '$personName owes you $amount';

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelDebtReminder(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// Everything still waiting to fire. Useful for checking that a
  /// reminder was actually registered during testing.
  Future<List<PendingNotificationRequest>> pending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }
}
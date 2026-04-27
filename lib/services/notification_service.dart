import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:adhera/services/localization_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _morningReminderId = 1001;
  static const int _eveningReminderId = 1002;
  static const int _demoDailyReminderId = 2001;
  static const int _demoMissedDoseAlertId = 2002;
  static const int _demoMissedDoseFollowupId = 2003;
  static const String _channelId = 'tb_medication_reminders';
  static const String _channelName = 'TB Medication Reminders';
  static const String _channelDescription =
      'Daily reminders for TB medication tracking.';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    await _createAndroidNotificationChannel();
    await _configureLocalTimezone();
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> syncForCurrentUser() async {
    if (kIsWeb) return;

    await initialize();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await cancelMedicationReminders();
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = userDoc.data()?['role'] as String?;
      if (role != 'patient') {
        await cancelMedicationReminders();
        return;
      }

      await _scheduleMorningReminder();
      await _scheduleEveningReminder(user.uid);
      await _logPendingNotifications();
    } catch (e) {
      debugPrint('Error syncing notifications: $e');
    }
  }

  Future<void> cancelMedicationReminders() async {
    await _notifications.cancel(_morningReminderId);
    await _notifications.cancel(_eveningReminderId);
  }

  Future<void> _scheduleMorningReminder() async {
    final content = _dailyReminderContent();

    await _scheduleDailyReminder(
      id: _morningReminderId,
      title: content.title,
      body: content.body,
      hour: 9,
    );
  }

  Future<void> _scheduleEveningReminder(String userId) async {
    final todayDoseTaken = await _isTodayDoseTaken(userId);

    if (todayDoseTaken) {
      await _notifications.cancel(_eveningReminderId);
      debugPrint('Cancelled evening reminder because today is already marked.');
      return;
    }

    final content = _missedDoseAlertContent();

    await _scheduleDailyReminder(
      id: _eveningReminderId,
      title: content.title,
      body: content.body,
      hour: 21,
    );
  }

  Future<void> showDailyReminderDemo() async {
    final content = _dailyReminderContent();
    await _showInstantNotification(
      id: _demoDailyReminderId,
      title: content.title,
      body: content.body,
    );
  }

  Future<void> showMissedDoseAlertDemo() async {
    final content = _missedDoseAlertContent();
    await _showInstantNotification(
      id: _demoMissedDoseAlertId,
      title: content.title,
      body: content.body,
    );
  }

  Future<void> showMissedDoseFollowupDemo() async {
    final content = _missedDoseFollowupContent();
    await _showInstantNotification(
      id: _demoMissedDoseFollowupId,
      title: content.title,
      body: content.body,
    );
  }

  Future<bool> _isTodayDoseTaken(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('doseLogs')
        .where('date', isEqualTo: today)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return false;
    }

    return snapshot.docs.first.data()['taken'] == true;
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails();

    return const NotificationDetails(android: android, iOS: ios);
  }

  tz.TZDateTime _nextInstanceOfTime({required int hour}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();

    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _requestPermissions() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _createAndroidNotificationChannel() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );
  }

  Future<void> _scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour: hour);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint(
      'Scheduled notification $id for ${scheduledTime.toIso8601String()}',
    );
  }

  Future<void> _logPendingNotifications() async {
    final pendingRequests = await _notifications.pendingNotificationRequests();
    debugPrint(
      'Pending notifications: ${pendingRequests.map((request) => request.id).toList()}',
    );
  }

  Future<void> _showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    await initialize();
    await _notifications.show(id, title, body, _notificationDetails());
  }

  _NotificationContent _dailyReminderContent() {
    switch (LocalizationService().locale.languageCode) {
      case 'fr':
        return const _NotificationContent(
          title: 'Il est temps de prendre votre traitement',
          body:
              'N’oubliez pas votre traitement antituberculeux aujourd’hui. La régularité est essentielle pour guérir.',
        );
      case 'ar':
        return const _NotificationContent(
          title: 'Ø­Ø§Ù† ÙˆÙ‚Øª ØªÙ†Ø§ÙˆÙ„ Ø§Ù„Ø¯ÙˆØ§Ø¡',
          body: 'Ù„Ø§ ØªÙ†Ø³ÙŽ ØªÙ†Ø§ÙˆÙ„ Ø¹Ù„Ø§Ø¬ Ø§Ù„Ø³Ù„ Ø§Ù„ÙŠÙˆÙ…. Ø§Ù„Ø§Ù†ØªØ¸Ø§Ù… Ù…Ù‡Ù… Ø¬Ø¯Ø§Ù‹ Ù„Ù„Ø´ÙØ§Ø¡.',
        );
      case 'en':
      default:
        return const _NotificationContent(
          title: 'Time to take your medication',
          body:
              'Donâ€™t forget your TB treatment today. Staying consistent is key to recovery.',
        );
    }
  }

  _NotificationContent _missedDoseAlertContent() {
    switch (LocalizationService().locale.languageCode) {
      case 'fr':
        return const _NotificationContent(
          title: 'Vous n’avez pas encore pris votre traitement',
          body:
              'Il n’est pas trop tard. Prendre votre dose aujourd’hui aide à maintenir votre traitement efficace.',
        );
      case 'ar':
        return const _NotificationContent(
          title: 'Ù„Ù… ØªØªÙ†Ø§ÙˆÙ„ Ø¯ÙˆØ§Ø¡Ùƒ Ø¨Ø¹Ø¯',
          body: 'Ù„Ø§ ÙŠØ²Ø§Ù„ Ø¨Ø¥Ù…ÙƒØ§Ù†Ùƒ ØªÙ†Ø§ÙˆÙ„Ù‡. Ø£Ø®Ø° Ø§Ù„Ø¬Ø±Ø¹Ø© Ø§Ù„ÙŠÙˆÙ… ÙŠØ³Ø§Ø¹Ø¯Ùƒ Ø¹Ù„Ù‰ Ø§Ù„Ø§Ø³ØªÙ…Ø±Ø§Ø± ÙÙŠ Ø§Ù„Ø¹Ù„Ø§Ø¬.',
        );
      case 'en':
      default:
        return const _NotificationContent(
          title: 'You havenâ€™t taken your medication yet',
          body:
              'Itâ€™s not too late. Taking your dose today helps keep your treatment on track.',
        );
    }
  }

  _NotificationContent _missedDoseFollowupContent() {
    switch (LocalizationService().locale.languageCode) {
      case 'fr':
        return const _NotificationContent(
          title: 'Avez-vous oublié votre dose d’hier ?',
          body:
              'L’oubli des doses peut affecter votre guérison. Essayez de rester régulier et prenez votre traitement aujourd’hui.',
        );
      case 'ar':
        return const _NotificationContent(
          title: 'Ù‡Ù„ ÙØ§ØªØªÙƒ Ø¬Ø±Ø¹Ø© Ø§Ù„Ø£Ù…Ø³ØŸ',
          body: 'Ù†Ø³ÙŠØ§Ù† Ø§Ù„Ø¬Ø±Ø¹Ø§Øª Ù‚Ø¯ ÙŠØ¤Ø«Ø± Ø¹Ù„Ù‰ Ø§Ù„Ø´ÙØ§Ø¡. Ø­Ø§ÙˆÙ„ Ø§Ù„Ø§Ù„ØªØ²Ø§Ù… ÙˆØªÙ†Ø§ÙˆÙ„ Ø¯ÙˆØ§Ø¡Ùƒ Ø§Ù„ÙŠÙˆÙ….',
        );
      case 'en':
      default:
        return const _NotificationContent(
          title: 'Did you miss yesterdayâ€™s dose?',
          body:
              'Missing doses can affect your recovery. Try to stay consistent and take todayâ€™s medication.',
        );
    }
  }
}

class _NotificationContent {
  const _NotificationContent({required this.title, required this.body});

  final String title;
  final String body;
}


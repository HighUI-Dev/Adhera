import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _morningReminderId = 1001;
  static const int _eveningReminderId = 1002;
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
    await _scheduleDailyReminder(
      id: _morningReminderId,
      title: 'Medication Reminder',
      body: 'Time to take your TB medication.',
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

    await _scheduleDailyReminder(
      id: _eveningReminderId,
      title: 'Evening Check-In',
      body:
          'If you have not taken your TB medication today, please take it and mark it as taken.',
      hour: 21,
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
}

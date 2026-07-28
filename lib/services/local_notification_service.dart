import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

class LocalNotificationService {
  static const _androidIcon = 'ic_stat_dojo';
  static const _bellSound = RawResourceAndroidNotificationSound('bell_dojo');
  static const _updateGroupKey = 'dojo_updates_group';
  static const _updateSummaryId = 49999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  ValueChanged<String>? _payloadHandler;
  String? _pendingPayload;

  static const _attendanceChannel = AndroidNotificationDetails(
    'attendance_reminders_bell_v2',
    'Pengingat Absensi',
    channelDescription: 'Pengingat clock in dan clock out intern',
    icon: _androidIcon,
    importance: Importance.max,
    priority: Priority.high,
    enableVibration: true,
    playSound: true,
    sound: _bellSound,
  );

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(_androidIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _deliverPayload(payload);
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _deliverPayload(launchPayload);
    }
  }

  void setPayloadHandler(ValueChanged<String>? handler) {
    _payloadHandler = handler;
    final pending = _pendingPayload;
    if (handler != null && pending != null) {
      _pendingPayload = null;
      handler(pending);
    }
  }

  void _deliverPayload(String payload) {
    final handler = _payloadHandler;
    if (handler == null) {
      _pendingPayload = payload;
    } else {
      handler(payload);
    }
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<void> scheduleAttendanceReminders() async {
    if (kIsWeb) return;
    await requestPermission();
    await cancelAttendanceReminders();

    for (var weekday = DateTime.monday; weekday <= DateTime.friday; weekday++) {
      await _scheduleWeekly(
        id: 1100 + weekday,
        weekday: weekday,
        hour: 8,
        minute: 0,
        title: 'Waktunya memulai bekerja',
        body: 'Selamat pagi! Jangan lupa Clock In dan mulai harimu di Dojo.',
        payload: 'attendance',
      );
      await _scheduleWeekly(
        id: 1105 + weekday,
        weekday: weekday,
        hour: 16,
        minute: 30,
        title: 'Waktunya selesai bekerja',
        body: 'Terima kasih untuk hari ini. Jangan lupa Clock Out di Dojo.',
        payload: 'attendance',
      );
    }
  }

  Future<void> cancelAttendanceReminders() async {
    if (kIsWeb) return;
    for (var id = 1101; id <= 1110; id++) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> showServerUpdate({
    required int id,
    required String title,
    required String body,
    required int unreadCount,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _plugin.show(
      id: 50000 + id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'dojo_updates_bell_v2',
          'Update Dojo',
          channelDescription: 'Update kegiatan dan pengajuan internship',
          icon: _androidIcon,
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          sound: _bellSound,
          groupKey: _updateGroupKey,
          number: 1,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBanner: true,
          badgeNumber: unreadCount,
          sound: 'bell-dojo.wav',
        ),
      ),
      payload: payload,
    );
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 180, 100, 240]);
      }
    }
  }

  Future<void> syncUnreadBadge(int unreadCount) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (unreadCount <= 0) {
      await clearServerUpdates();
      return;
    }
    try {
      await _plugin.show(
        id: _updateSummaryId,
        title: 'Dojo',
        body: '$unreadCount notifikasi belum dibaca',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'dojo_updates',
            'Update Dojo',
            channelDescription: 'Update kegiatan dan pengajuan internship',
            icon: _androidIcon,
            importance: Importance.high,
            priority: Priority.high,
            groupKey: _updateGroupKey,
            setAsGroupSummary: true,
            number: unreadCount,
            onlyAlertOnce: true,
            silent: true,
          ),
        ),
        payload: 'notifications',
      );
    } catch (_) {
      // Some Android launchers do not expose numeric badge support.
    }
  }

  Future<void> dismissServerUpdate(int id, int remainingUnread) async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: 50000 + id);
      await syncUnreadBadge(remainingUnread);
    } catch (_) {
      // Reading notifications in-app must still succeed if badge sync fails.
    }
  }

  Future<void> clearServerUpdates() async {
    if (kIsWeb) return;
    try {
      final active = await _plugin.getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        if (id != null && (id == _updateSummaryId || id >= 50000)) {
          await _plugin.cancel(id: id);
        }
      }
    } catch (_) {
      try {
        await _plugin.cancel(id: _updateSummaryId);
      } catch (_) {
        // Badge cleanup is best-effort on unsupported platforms/launchers.
      }
    }
  }

  Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextWeekdayTime(weekday, hour, minute),
      notificationDetails: const NotificationDetails(
        android: _attendanceChannel,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBanner: true,
          sound: 'bell-dojo.wav',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

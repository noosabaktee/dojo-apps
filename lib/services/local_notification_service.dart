import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  ValueChanged<String>? _payloadHandler;
  String? _pendingPayload;

  static const _attendanceChannel = AndroidNotificationDetails(
    'attendance_reminders',
    'Pengingat Absensi',
    channelDescription: 'Pengingat clock in dan clock out intern',
    importance: Importance.max,
    priority: Priority.high,
    enableVibration: true,
    playSound: true,
  );

  static const _updateChannel = AndroidNotificationDetails(
    'dojo_updates',
    'Update Dojo',
    channelDescription: 'Update kegiatan dan pengajuan internship',
    importance: Importance.high,
    priority: Priority.high,
    enableVibration: true,
  );

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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

  Future<void> scheduleAttendanceReminders(
    Map<String, dynamic> settings,
  ) async {
    if (kIsWeb) return;
    await requestPermission();
    for (var id = 1101; id <= 1110; id++) {
      await _plugin.cancel(id: id);
    }

    final clockIn = _parseTime(settings['clock_in_start']?.toString(), 8, 0);
    final clockOut = _parseTime(settings['clock_out_start']?.toString(), 17, 0);
    final checkInTime = _minusMinutes(clockIn.$1, clockIn.$2, 15);
    final checkOutTime = _minusMinutes(clockOut.$1, clockOut.$2, 10);

    for (var weekday = DateTime.monday; weekday <= DateTime.friday; weekday++) {
      await _scheduleWeekly(
        id: 1100 + weekday,
        weekday: weekday,
        hour: checkInTime.$1,
        minute: checkInTime.$2,
        title: 'Jangan lupa Clock In',
        body:
            'Siapkan Face ID dan lokasi. Clock In dibuka pukul '
            '${_hhmm(clockIn.$1, clockIn.$2)} WIB.',
        payload: 'attendance',
      );
      await _scheduleWeekly(
        id: 1105 + weekday,
        weekday: weekday,
        hour: checkOutTime.$1,
        minute: checkOutTime.$2,
        title: 'Waktunya bersiap Clock Out',
        body: 'Pastikan Clock Out tercatat sebelum meninggalkan lokasi kerja.',
        payload: 'attendance',
      );
    }
  }

  Future<void> showServerUpdate({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: 50000 + id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _updateChannel,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBanner: true,
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

  (int, int) _parseTime(String? value, int fallbackHour, int fallbackMinute) {
    final parts = value?.split(':');
    if (parts == null || parts.length < 2) {
      return (fallbackHour, fallbackMinute);
    }
    return (
      int.tryParse(parts[0]) ?? fallbackHour,
      int.tryParse(parts[1]) ?? fallbackMinute,
    );
  }

  (int, int) _minusMinutes(int hour, int minute, int delta) {
    final total = (hour * 60 + minute - delta) % (24 * 60);
    return (total ~/ 60, total % 60);
  }

  String _hhmm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

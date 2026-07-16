import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';

class AppRepository {
  AppRepository(this.client);

  final ApiClient client;

  Future<AppUser> login(String email, String password) async {
    final result = await client.post(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
        'device_name': await _deviceName(),
      },
    );
    final data = asMap(result.data);
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Token login tidak ditemukan.');
    }
    await client.saveToken(token);
    return AppUser.fromJson(asMap(data['user']));
  }

  Future<AppUser> me() async {
    final result = await client.get('/me');
    return AppUser.fromJson(asMap(result.data));
  }

  Future<void> logout() async {
    try {
      await client.post('/auth/logout');
    } finally {
      await client.clearToken();
    }
  }

  Future<Map<String, dynamic>> dashboard() async =>
      asMap((await client.get('/dashboard')).data);

  Future<Map<String, dynamic>> leaderboard() async =>
      asMap((await client.get('/leaderboard')).data);

  Future<Map<String, dynamic>> attendance({int perPage = 50}) async => asMap(
    (await client.get(
      '/attendance',
      queryParameters: {'per_page': perPage},
    )).data,
  );

  Future<Map<String, dynamic>> attendanceAction({
    required bool checkIn,
    required Uint8List imageBytes,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final dataUri = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    return asMap(
      (await client.post(
        checkIn ? '/attendance/check-in' : '/attendance/check-out',
        data: {
          'image': dataUri,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'device': await _deviceName(),
        },
      )).data,
    );
  }

  Future<void> enrollFace(List<Uint8List> images) async {
    await client.post(
      '/profile/face-enrollment',
      data: {
        'images': images
            .map((bytes) => 'data:image/jpeg;base64,${base64Encode(bytes)}')
            .toList(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> calendarEvents({
    String? from,
    String? to,
  }) async {
    final result = await client.get(
      '/calendar-sharings',
      queryParameters: {'per_page': 100, 'from': ?from, 'to': ?to},
    );
    return asMapList(result.data);
  }

  Future<List<Map<String, dynamic>>> evaluations(AppUser user) async {
    final path = user.isIntern ? '/me/evaluations' : '/evaluations';
    final result = await client.get(
      path,
      queryParameters: user.isIntern ? null : {'per_page': 100},
    );
    return asMapList(result.data);
  }

  Future<List<Map<String, dynamic>>> interns() async {
    final result = await client.get(
      '/interns',
      queryParameters: {'per_page': 100},
    );
    return asMapList(result.data);
  }

  Future<List<Map<String, dynamic>>> wfhRequests({String? status}) async {
    final result = await client.get(
      '/work-from-home',
      queryParameters: {'per_page': 100, 'status': ?status},
    );
    return asMapList(result.data);
  }

  Future<String> reviewWfh(
    int id, {
    required bool approve,
    String? note,
  }) async {
    final result = await client.post(
      '/work-from-home/$id/${approve ? 'approve' : 'reject'}',
      data: {if (note != null && note.isNotEmpty) 'review_note': note},
    );
    return result.message;
  }

  Future<List<Map<String, dynamic>>> notifications({
    bool unreadOnly = false,
  }) async {
    final result = await client.get(
      '/notifications',
      queryParameters: {'per_page': 100, if (unreadOnly) 'filter': 'unread'},
    );
    return asMapList(result.data);
  }

  Future<void> markNotificationRead(int id) async {
    await client.patch('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await client.post('/notifications/read-all');
  }

  Future<String> _deviceName() async {
    if (kIsWeb) return 'Dojo Web';
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return 'Android ${android.manufacturer} ${android.model}'.trim();
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return 'iOS ${ios.name} ${ios.model}'.trim();
      }
    } catch (_) {
      // A generic name is sufficient if platform information is unavailable.
    }
    return 'Dojo Mobile';
  }

  static FormData multipart({required Map<String, dynamic> fields}) =>
      FormData.fromMap(fields);
}

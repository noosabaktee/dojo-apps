import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiEnvelope {
  const ApiEnvelope({required this.data, required this.message, this.meta});

  final dynamic data;
  final String message;
  final Map<String, dynamic>? meta;
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  @override
  String toString() => message;
}

class DownloadedFile {
  const DownloadedFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class ApiClient {
  ApiClient({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 35),
          sendTimeout: const Duration(seconds: 45),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/login')) {
            await clearToken();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.8.176:8000/api/v1',
  );
  static const _tokenKey = 'dojo_api_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  VoidCallback? onUnauthorized;

  static String? publicFileUrl(String? path) {
    final value = path?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed?.hasScheme == true) return value;
    final apiUri = Uri.parse(baseUrl);
    final segments = [...apiUri.pathSegments];
    final apiIndex = segments.indexOf('api');
    final publicSegments = apiIndex >= 0
        ? segments.take(apiIndex).toList()
        : <String>[];
    final normalized = value
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'^storage/+'), '');
    return apiUri
        .replace(
          pathSegments: [
            ...publicSegments,
            'storage',
            ...normalized.split('/').where((segment) => segment.isNotEmpty),
          ],
        )
        .toString();
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: _tokenKey))?.isNotEmpty == true;

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _request(() => _dio.get<dynamic>(path, queryParameters: queryParameters));

  Future<ApiEnvelope> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) => _request(
    () =>
        _dio.post<dynamic>(path, data: data, queryParameters: queryParameters),
  );

  Future<ApiEnvelope> patch(String path, {dynamic data}) =>
      _request(() => _dio.patch<dynamic>(path, data: data));

  Future<ApiEnvelope> delete(String path, {dynamic data}) =>
      _request(() => _dio.delete<dynamic>(path, data: data));

  Future<DownloadedFile> getFile(
    String path, {
    String fallbackName = 'dokumen',
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      final raw = response.data;
      final bytes = raw is Uint8List
          ? raw
          : Uint8List.fromList(raw is List<int> ? raw : const []);
      if (bytes.isEmpty) {
        throw const ApiException('File yang diterima kosong.');
      }
      final disposition = response.headers.value('content-disposition');
      return DownloadedFile(
        bytes: bytes,
        fileName: _fileName(disposition) ?? fallbackName,
        contentType:
            response.headers.value(Headers.contentTypeHeader) ??
            'application/octet-stream',
      );
    } on DioException catch (error) {
      Map<String, dynamic>? json;
      final body = error.response?.data;
      try {
        if (body is List<int>) {
          final decoded = jsonDecode(utf8.decode(body));
          if (decoded is Map) json = Map<String, dynamic>.from(decoded);
        } else if (body is Map) {
          json = Map<String, dynamic>.from(body);
        }
      } catch (_) {
        // A binary/non-JSON error response falls back to the network message.
      }
      throw ApiException(
        json?['message']?.toString() ?? _networkMessage(error),
        statusCode: error.response?.statusCode,
        errors: _mapOrNull(json?['errors']),
      );
    }
  }

  Future<ApiEnvelope> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is! Map) {
        throw const ApiException('Respons server tidak dapat dibaca.');
      }
      final json = Map<String, dynamic>.from(body);
      if (json['success'] == false) {
        final errors = _mapOrNull(json['errors']);
        throw ApiException(
          _readableMessage(
            json['message']?.toString(),
            errors,
            'Permintaan gagal.',
          ),
          statusCode: response.statusCode,
          errors: errors,
        );
      }
      return ApiEnvelope(
        data: json['data'],
        message: json['message']?.toString() ?? 'Berhasil.',
        meta: _mapOrNull(json['meta']),
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      final json = body is Map ? Map<String, dynamic>.from(body) : null;
      final errors = _mapOrNull(json?['errors']);
      final message = _readableMessage(
        json?['message']?.toString(),
        errors,
        _networkMessage(error),
      );
      throw ApiException(
        message,
        statusCode: error.response?.statusCode,
        errors: errors,
      );
    }
  }

  static String _networkMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'Koneksi ke server terlalu lama. Coba lagi.',
      DioExceptionType.connectionError =>
        'Tidak dapat terhubung ke server. Periksa koneksi dan alamat API.',
      _ => 'Terjadi gangguan saat menghubungi server.',
    };
  }

  static String? _fileName(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;
    final utf8Name = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    if (utf8Name != null) return Uri.decodeComponent(utf8Name);
    return RegExp(
      'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
  }
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _readableMessage(
  String? message,
  Map<String, dynamic>? errors,
  String fallback,
) {
  if (errors != null && errors.isNotEmpty) {
    final messages = <String>[];
    for (final value in errors.values) {
      if (value is List) {
        messages.addAll(
          value
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty),
        );
      } else {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) messages.add(text);
      }
    }
    if (messages.isNotEmpty) return messages.toSet().join('\n');
  }

  final normalized = message?.trim();
  return normalized?.isNotEmpty == true ? normalized! : fallback;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

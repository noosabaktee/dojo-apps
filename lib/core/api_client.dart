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
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  static const _tokenKey = 'dojo_api_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  VoidCallback? onUnauthorized;

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
        throw ApiException(
          json['message']?.toString() ?? 'Permintaan gagal.',
          statusCode: response.statusCode,
          errors: _mapOrNull(json['errors']),
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
      final message = json?['message']?.toString() ?? _networkMessage(error);
      throw ApiException(
        message,
        statusCode: error.response?.statusCode,
        errors: _mapOrNull(json?['errors']),
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
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
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

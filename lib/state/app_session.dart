import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../repositories/app_repository.dart';

class AppSession extends ChangeNotifier {
  AppSession(this.repository);

  final AppRepository repository;
  AppUser? user;
  bool isBootstrapping = true;
  bool isSubmitting = false;
  String? error;

  Future<void> bootstrap({Duration minimumDuration = Duration.zero}) async {
    final startedAt = DateTime.now();
    isBootstrapping = true;
    notifyListeners();
    try {
      if (await repository.client.hasToken()) {
        user = await repository.me();
      }
    } on ApiException {
      await repository.client.clearToken();
      user = null;
    } finally {
      final remaining = minimumDuration - DateTime.now().difference(startedAt);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    isSubmitting = true;
    error = null;
    notifyListeners();
    try {
      user = await repository.login(email, password);
      return true;
    } on ApiException catch (exception) {
      error = _fieldMessage(exception) ?? exception.message;
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    isSubmitting = true;
    notifyListeners();
    try {
      await repository.logout();
    } finally {
      user = null;
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<AppUser> refreshUser() async {
    final refreshed = await repository.me();
    user = refreshed;
    notifyListeners();
    return refreshed;
  }

  void expire() {
    user = null;
    error = 'Sesi berakhir. Silakan masuk kembali.';
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  String? _fieldMessage(ApiException exception) {
    final errors = exception.errors;
    if (errors == null || errors.isEmpty) return null;
    final value = errors.values.first;
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value?.toString();
  }
}

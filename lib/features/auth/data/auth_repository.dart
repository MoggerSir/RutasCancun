import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:rutas_cancun/core/auth/auth_tokens.dart';
import 'package:rutas_cancun/core/network/dio_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(baseDioProvider));
});

final authInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString(deviceIdKey);
  deviceId ??= const Uuid().v4();
  await prefs.setString(deviceIdKey, deviceId);

  final repo = ref.read(authRepositoryProvider);
  // Token fresco al arrancar (JWT dura 7 días; evita 401 silencioso en prefs viejos)
  final token = await repo.loginAnonymous(deviceId);
  await prefs.setString(tokenKey, token);
  ref.read(authTokenProvider.notifier).state = token;
});

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(onboardingKey) ?? false;
});

Future<void> completeOnboarding(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(onboardingKey, true);
  ref.invalidate(onboardingDoneProvider);
}

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<String> loginAnonymous(String deviceId) async {
    final res = await _dio.post('/auth/anonymous', data: {'deviceId': deviceId});
    return res.data['accessToken'] as String;
  }
}

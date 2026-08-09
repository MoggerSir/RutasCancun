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
  AuthSessionTokens? tokens;
  final storedRefresh = prefs.getString(refreshTokenKey);
  if (storedRefresh != null && storedRefresh.isNotEmpty) {
    try {
      tokens = await repo.refresh(storedRefresh);
    } catch (_) {
      await prefs.remove(refreshTokenKey);
    }
  }
  tokens ??= await repo.loginAnonymous(deviceId);
  await _persistTokens(prefs, tokens);
  ref.read(authTokenProvider.notifier).state = tokens.accessToken;
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

  Future<AuthSessionTokens> loginAnonymous(String deviceId) async {
    final res =
        await _dio.post('/auth/anonymous', data: {'deviceId': deviceId});
    return AuthSessionTokens.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthSessionTokens> refresh(String refreshToken) async {
    final res = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthSessionTokens.fromJson(res.data as Map<String, dynamic>);
  }
}

class AuthSessionTokens {
  const AuthSessionTokens({required this.accessToken, this.refreshToken});

  factory AuthSessionTokens.fromJson(Map<String, dynamic> json) {
    return AuthSessionTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
    );
  }

  final String accessToken;
  final String? refreshToken;
}

Future<void> _persistTokens(
  SharedPreferences prefs,
  AuthSessionTokens tokens,
) async {
  await prefs.setString(tokenKey, tokens.accessToken);
  final refreshToken = tokens.refreshToken;
  if (refreshToken != null && refreshToken.isNotEmpty) {
    await prefs.setString(refreshTokenKey, refreshToken);
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rutas_cancun/core/config/api_config.dart';
import 'package:rutas_cancun/core/auth/auth_tokens.dart';

/// Dio sin interceptor de auth — usado para login y refresh JWT.
final baseDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = ref.read(authTokenProvider);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        final retried = await _refreshTokenAndRetry(ref, dio, error.requestOptions);
        if (retried != null) {
          return handler.resolve(retried);
        }
      }
      handler.next(error);
    },
  ));

  return dio;
});

/// Renueva JWT vía /auth/anonymous con el mismo deviceId y reintenta la petición.
Future<Response<dynamic>?> _refreshTokenAndRetry(
  Ref ref,
  Dio dio,
  RequestOptions requestOptions,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(deviceIdKey);
    if (deviceId == null || deviceId.length < 8) return null;

    final baseDio = ref.read(baseDioProvider);
    final res = await baseDio.post('/auth/anonymous', data: {'deviceId': deviceId});
    final newToken = res.data['accessToken'] as String;

    await prefs.setString(tokenKey, newToken);
    ref.read(authTokenProvider.notifier).state = newToken;

    final opts = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $newToken',
      },
    );
    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: opts,
    );
  } catch (_) {
    return null;
  }
}

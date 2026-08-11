import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rutas_cancun/core/config/api_config.dart';
import 'package:rutas_cancun/core/auth/auth_tokens.dart';

Future<String?>? _refreshInFlight;

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
      if (error.response?.statusCode == 401 &&
          error.requestOptions.extra['authRetried'] != true) {
        final retried =
            await _refreshTokenAndRetry(ref, dio, error.requestOptions);
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
    final newToken = await _singleFlightRefresh(ref);
    if (newToken == null) return null;
    ref.read(authTokenProvider.notifier).state = newToken;

    requestOptions.extra['authRetried'] = true;
    final opts = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $newToken',
      },
      extra: requestOptions.extra,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      followRedirects: requestOptions.followRedirects,
      receiveTimeout: requestOptions.receiveTimeout,
      sendTimeout: requestOptions.sendTimeout,
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

Future<String?> _singleFlightRefresh(Ref ref) async {
  final running = _refreshInFlight;
  if (running != null) return running;

  final operation = _refreshCredentials(ref);
  _refreshInFlight = operation;
  try {
    return await operation;
  } finally {
    if (identical(_refreshInFlight, operation)) {
      _refreshInFlight = null;
    }
  }
}

Future<String?> _refreshCredentials(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  final baseDio = ref.read(baseDioProvider);
  Map<String, dynamic>? payload;
  final storedRefresh = prefs.getString(refreshTokenKey);

  if (storedRefresh != null && storedRefresh.isNotEmpty) {
    try {
      final response = await baseDio.post(
        '/auth/refresh',
        data: {'refreshToken': storedRefresh},
      );
      payload = response.data as Map<String, dynamic>;
    } catch (_) {
      await prefs.remove(refreshTokenKey);
    }
  }

  if (payload == null) {
    final deviceId = prefs.getString(deviceIdKey);
    if (deviceId == null || deviceId.length < 8) return null;
    final response = await baseDio.post(
      '/auth/anonymous',
      data: {'deviceId': deviceId},
    );
    payload = response.data as Map<String, dynamic>;
  }

  final accessToken = payload['accessToken'] as String?;
  if (accessToken == null || accessToken.isEmpty) return null;
  await prefs.setString(tokenKey, accessToken);
  final newRefresh = payload['refreshToken'] as String?;
  if (newRefresh != null && newRefresh.isNotEmpty) {
    await prefs.setString(refreshTokenKey, newRefresh);
  }
  return accessToken;
}

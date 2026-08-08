class ApiConfig {
  static const productionBaseUrl =
      'https://rutascancun.larpmusic.com.mx/api';

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionBaseUrl,
  );
}

class ApiConfig {
  static const productionBaseUrl = 'https://api.rutascancun.com/api';

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionBaseUrl,
  );
}

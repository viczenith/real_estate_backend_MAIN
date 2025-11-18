class Config {
  // Base URLs - PRODUCTION should use Render backend
  // LOCAL development uses localhost
  static const String devBaseUrl = 'http://10.54.177.72:8000';
  static const String prodBaseUrl = 'https://lamba-backend.onrender.com';

  // API Versioning
  static const String apiVersion = '/api/v1';

  /// Get the base URL - MUST use Render for Firebase App Distribution
  /// Set _useProductionBackend to false ONLY for local development testing
  static String get baseUrl {
    // ⚠️ CRITICAL: For Firebase App Distribution, this MUST be true
    // Change to false ONLY when debugging with localhost
    return _useProductionBackend ? prodBaseUrl : devBaseUrl;
  }

  // Toggle between production (Render) and local development
  // For Firebase App Distribution: MUST BE TRUE
  static const bool _useProductionBackend = true;

  // Default headers for API requests
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };

  // API Endpoints - Use full paths including /api prefix
  static const String loginEndpoint = '$apiVersion/api-token-auth/';
  static const String supportBirthdaySummary =
      '$apiVersion/support/birthday-summary/';
  static const String supportSpecialDayCounts =
      '$apiVersion/support/special-day-counts/';
  static const String supportBirthdayCounts =
      '$apiVersion/support/birthday-counts/';
}

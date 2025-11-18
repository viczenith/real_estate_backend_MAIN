class Config {
  // Base URLs - Remove /api from base URLs as it's included in the endpoints
  static const String devBaseUrl = 'http://10.54.177.72:8000';
  static const String prodBaseUrl = 'https://lamba-backend.onrender.com';
  
  // API Versioning
  static const String apiVersion = '/api/v1';
  
  static String get baseUrl {
    const bool isProduction = true;
    return isProduction ? prodBaseUrl : devBaseUrl;
  }
  
  // API Endpoints - Use full paths including /api prefix
  static const String loginEndpoint = '$apiVersion/api-token-auth/';
}

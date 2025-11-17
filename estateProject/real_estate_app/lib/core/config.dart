class Config {
  // Base URLs
  static const String devBaseUrl = 'http://10.54.177.72:8000/api';
  static const String prodBaseUrl = 'https://lamba-backend.onrender.com/api';
  
  static String get baseUrl {
    const bool isProduction = true;
    return isProduction ? prodBaseUrl : devBaseUrl;
  }
  
  // API Endpoints
  static const String loginEndpoint = '/api-token-auth/';
  static const String supportBirthdaySummary = '/admin-support/birthdays/summary/';
  static const String supportSpecialDayCounts = '/admin-support/special-days/counts/';
  static const String supportBirthdayCounts = '/admin-support/birthdays/counts/';
  // Add other endpoints as needed
}

class ApiConstants {
  static const String baseUrl = "http://127.0.0.1:8000/api/v1";
  
  // Auth Endpoints
  static const String login = "$baseUrl/accounts/auth/login/";
  static const String refreshToken = "$baseUrl/accounts/auth/token/refresh/";
  static const String trackLocation = "$baseUrl/accounts/user/track-location/";
}
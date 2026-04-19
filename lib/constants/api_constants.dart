class ApiConstants {
  // Use 10.0.2.2 for Android Emulator, your IP for physical devices
  static const String baseUrl = "http://127.0.0.1:8000/api/v1";
  static const String baseUrlV2 = "http://127.0.0.1:8000/api/v2";

  // Auth Endpoints
  static const String login = "$baseUrl/accounts/auth/login/";
  static const String refreshToken = "$baseUrl/accounts/auth/token/refresh/";
  static const String userLocation = "$baseUrl/accounts/user/location/";
  static const String trackLocation = "$baseUrl/accounts/user/track-location/";

  static const String homeData = "$baseUrlV2/wast/customer/home/";
}

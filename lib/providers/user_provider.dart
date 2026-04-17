import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _authData;

  Map<String, dynamic>? get user => _userData;
  Map<String, dynamic>? get authData => _authData;

  bool get isAuthenticated => _authData != null;

  void setUser(Map<String, dynamic> response) {
    _userData = response['user'] as Map<String, dynamic>?;
    _authData = response['data'] as Map<String, dynamic>?;
    notifyListeners();
  }

  void logout() {
    _userData = null;
    _authData = null;
    notifyListeners();
  }
}
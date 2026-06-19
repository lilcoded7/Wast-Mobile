import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';

/// Navigate to the correct home screen after a successful login.
Future<void> navigateAfterLogin(BuildContext context, Map<String, dynamic> data) async {
  await ApiService.saveTokens(
    access: data['tokens']['access'] as String,
    refresh: data['tokens']['refresh'] as String,
  );
  if (!context.mounted) return;

  final provider = Provider.of<AppProvider>(context, listen: false);
  provider.setCurrentUser(Map<String, dynamic>.from(data['user'] as Map));

  final role = data['user']['role'] as String? ?? 'customer';
  String route;
  switch (role) {
    case 'admin':
      route = '/admin-home';
      break;
    case 'collector':
      route = '/collector-home';
      break;
    case 'investor':
      route = '/investor-home';
      break;
    default:
      route = '/home';
  }
  Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
}

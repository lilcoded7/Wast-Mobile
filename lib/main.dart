import 'package:flutter/material.dart';
import 'auth/login.dart';
import 'auth/register.dart';
import 'home/home_screen.dart';
import 'home/schedule_pickup.dart';
import 'home/tracking_page.dart'; // Create this file in lib/tracking/

void main() {
  runApp(const WasteApp());
}

class WasteApp extends StatelessWidget {
  const WasteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WastePick',
      theme: ThemeData(
        primaryColor: Colors.green[700],
        useMaterial3: true,
        fontFamily:
            'Inter', // If you have the font, otherwise it defaults to system
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomeScreen(),
        '/schedule': (context) => const SchedulePickupPage(),
        '/tracking': (context) => const TrackingPage(),
      },
    );
  }
}

import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../providers/user_provider.dart';
import '../constants/api_constants.dart';

import 'history.dart';
import 'profile_screen.dart';
import 'request.dart';
import 'schedule_pickup.dart';
import 'report_dumping.dart';
import 'tracking_page.dart';
import 'notification.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _trackingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndStartTracking();
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  void _checkAuthAndStartTracking() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!userProvider.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _trackingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _sendLocationUpdate();
    });
  }

  Future<void> _sendLocationUpdate() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.isAuthenticated) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.post(
        Uri.parse(ApiConstants.trackLocation),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${userProvider.authData?['access']}",
        },
        body: jsonEncode({
          "latitude": position.latitude,
          "longitude": position.longitude,
        }),
      );

      if (response.statusCode == 401) {
        _handleSessionExpired();
      }
    } catch (e) {
      debugPrint("Location update failed: $e");
    }
  }

  void _handleSessionExpired() {
    _trackingTimer?.cancel();
    Provider.of<UserProvider>(context, listen: false).logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userData = userProvider.user;
    final collectorData = userProvider.authData?['collector'];

    final displayName = collectorData?['first_name'] ?? userData?['phone_number'] ?? "User";

    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);
    const Color organicGreen = Color(0xFF8BCA3E);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFD4E7D4)),
              child: Opacity(
                opacity: 0.3,
                child: GridPaper(
                  color: Colors.green.withOpacity(0.3),
                  divisions: 1,
                  subdivisions: 1,
                  interval: 100,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    bgColor.withOpacity(0.8),
                    bgColor,
                  ],
                  stops: const [0.0, 0.4, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome back,",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationPage(),
                              ),
                            );
                          },
                          child: _buildNotificationBell(),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text(
                        "Active Request",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TrackingPage(),
                            ),
                          );
                        },
                        child: _buildActiveRequestCard(
                          cardColor,
                          organicGreen,
                          accentGreen,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Quick Actions",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildActionBtn(
                            context,
                            "Request\nPickup",
                            Icons.delete_outline,
                            cardColor,
                            const Color(0xFF4CAF50),
                            const RequestPickupPage(),
                          ),
                          _buildActionBtn(
                            context,
                            "Schedule",
                            Icons.calendar_month_outlined,
                            cardColor,
                            const Color(0xFF2196F3),
                            const SchedulePickupPage(),
                          ),
                          _buildActionBtn(
                            context,
                            "Report\nDump",
                            Icons.report_problem_outlined,
                            cardColor,
                            const Color(0xFFF44336),
                            const ReportDumpPage(),
                          ),
                          _buildActionBtn(
                            context,
                            "History",
                            Icons.history_outlined,
                            cardColor,
                            Colors.white70,
                            const ServiceHistoryPage(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Waste Types",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildWasteTypeCard(
                              "General",
                              "GH₵ 20",
                              Icons.delete_sweep,
                              Colors.grey.shade400,
                              cardColor,
                            ),
                            _buildWasteTypeCard(
                              "Recyclable",
                              "GH₵ 20",
                              Icons.recycling_rounded,
                              Colors.lightBlueAccent,
                              cardColor,
                            ),
                            _buildWasteTypeCard(
                              "Organic",
                              "GH₵ 20",
                              Icons.eco_rounded,
                              organicGreen,
                              cardColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 120),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, bgColor, accentGreen),
    );
  }

  Widget _buildNotificationBell() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFE57373),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: const Text(
              "10",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRequestCard(
    Color cardBg,
    Color organic,
    Color trackColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge("Organic", organic, Icons.eco),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5ED5A8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.near_me_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Track",
                    style: TextStyle(
                      color: Color(0xFF5ED5A8),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Text(
            "14 Ring Road East, Accra",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildStatusBadge("Pending", const Color(0xFFFFC107)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, color: Color(0xFF5ED5A8), size: 20),
                SizedBox(width: 10),
                Text(
                  "ETA: 10-15 min",
                  style: TextStyle(
                    color: Color(0xFF5ED5A8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    BuildContext context,
    String label,
    IconData icon,
    Color bg,
    Color iconColor,
    Widget targetPage,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      },
      child: Container(
        width: 82,
        height: 105,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteTypeCard(
    String title,
    String price,
    IconData icon,
    Color accent,
    Color bg,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(18),
      width: 150,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(title, accent, icon),
          const SizedBox(height: 16),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                height: 6,
                width: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, Color bg, Color activeColor) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 25),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.home_filled, "Home", true, activeColor, null),
          _navItem(
            context,
            Icons.history_rounded,
            "History",
            false,
            activeColor,
            const ServiceHistoryPage(),
          ),
          _navItem(
            context,
            Icons.person_2_outlined,
            "Profile",
            false,
            activeColor,
            const ProfilePage(),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    Color activeColor,
    Widget? target,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (!isActive && target != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => target),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? activeColor : Colors.white38, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white38,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
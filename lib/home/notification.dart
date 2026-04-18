import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.authData?['access'];

    const String url = "http://127.0.0.1:8000/api/v2/wast/notification/list/";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _notifications = data['results'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error: $e");
    }
  }

  // MODAL TO VIEW NOTIFICATION DETAILS
  void _viewNotificationDetails(Map<String, dynamic> item, Color accent) {
    String formattedTime = "Recently";
    try {
      DateTime dt = DateTime.parse(item['created_at']);
      formattedTime = DateFormat('EEEE, dd MMM yyyy • hh:mm a').format(dt);
    } catch (e) {
      formattedTime = "Notification Details";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF132314),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_active, color: accent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item['title'] ?? 'Notification',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  formattedTime,
                  style: TextStyle(
                    color: accent.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Text(
                  item['message'] ?? 'No message provided.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Dismiss",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color iconBgColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGreen))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _notifications[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _viewNotificationDetails(item, accentGreen),
                  child: _buildNotificationItem(
                    item['title'] ?? 'No Title',
                    item['message'] ?? '...',
                    item['created_at'],
                    item['is_read'] ?? true,
                    iconBgColor,
                    accentGreen,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String desc,
    String timestamp,
    bool isRead,
    Color iconBg,
    Color accent,
  ) {
    String formattedTime = "Recently";
    try {
      DateTime dt = DateTime.parse(timestamp);
      formattedTime = DateFormat('dd MMM').format(dt);
    } catch (e) {
      formattedTime = "";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(Icons.local_shipping_outlined, color: accent, size: 24),
              ),
              if (!isRead)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF061405), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formattedTime,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
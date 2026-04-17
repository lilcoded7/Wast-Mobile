import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color iconBgColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);

    // Mock data based on the provided design
    final List<Map<String, String>> notifications = [
      {
        "title": "Pickup Complete!",
        "desc": "Your waste has been collected. Please rate Abena Mensah's service.",
        "time": "7d ago"
      },
      {
        "title": "Collector Has Arrived!",
        "desc": "Abena Mensah is at your location. Please bring out your waste.",
        "time": "7d ago"
      },
      {
        "title": "Collector En Route",
        "desc": "Abena Mensah is heading to your location.",
        "time": "7d ago"
      },
      {
        "title": "Collector Assigned!",
        "desc": "Abena Mensah accepted your request. ETA: 12 min",
        "time": "7d ago"
      },
      {
        "title": "Request Submitted",
        "desc": "Your general waste pickup has been requested. Finding a collector...",
        "time": "7d ago"
      },
      {
        "title": "Pickup Complete!",
        "desc": "Your waste has been collected. Please rate Abena Mensah's service.",
        "time": "8d ago"
      },
    ];

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
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return _buildNotificationItem(
            item['title']!,
            item['desc']!,
            item['time']!,
            iconBgColor,
            accentGreen,
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String desc,
    String time,
    Color iconBg,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent, // Keeping it simple per design
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. STATUS ICON
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_shipping_outlined, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          
          // 2. TEXT CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
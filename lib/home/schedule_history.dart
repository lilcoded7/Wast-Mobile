import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

const Color _kBg = Color(0xFFF0F7F0);
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

class ScheduledPickupsPage extends StatelessWidget {
  const ScheduledPickupsPage({super.key});

  // Parse YYYY-MM-DD → "Monday, 22 May 2026"
  String _formatDateWithDay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      const days = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final dayName = days[dt.weekday - 1];
      return '$dayName, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final pickups = provider.scheduledPickups;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Schedules',
          style: TextStyle(
            color: _kTextDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: pickups.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 64, color: _kTextGray),
                  SizedBox(height: 16),
                  Text(
                    'No scheduled pickups yet',
                    style: TextStyle(color: _kTextGray, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: pickups.length,
              itemBuilder: (context, index) {
                return _scheduleCard(pickups[index]);
              },
            ),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> item) {
    final wasteType = item['wasteType']?.toString() ?? 'General';
    final dateStr = item['date']?.toString() ?? '';
    final time = item['time']?.toString() ?? '';
    final frequency = item['frequency']?.toString() ?? 'Once';
    final formattedDate = _formatDateWithDay(dateStr);

    // Extract short day name for the icon
    String shortDay = '';
    try {
      final dt = DateTime.parse(dateStr);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      shortDay = days[dt.weekday - 1];
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Day icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _kLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (shortDay.isNotEmpty)
                  Text(
                    shortDay,
                    style: const TextStyle(
                      color: _kPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const Icon(Icons.calendar_month,
                    color: _kPrimary, size: 20),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wasteType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate.isNotEmpty
                      ? '$formattedDate at $time'
                      : 'at $time',
                  style: const TextStyle(color: _kTextGray, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Repeats: $frequency',
                  style: const TextStyle(color: _kTextGray, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kLightGreen,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimary),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                color: _kPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

const Color _kBg = Color(0xFFF0F7F0);
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

class SchedulePickupPage extends StatefulWidget {
  const SchedulePickupPage({super.key});

  @override
  State<SchedulePickupPage> createState() => _SchedulePickupPageState();
}

class _SchedulePickupPageState extends State<SchedulePickupPage> {
  String? selectedDate;
  String selectedTime = '09:00';
  String selectedWaste = 'General';
  bool isRecurring = false;
  String selectedFrequency = 'Weekly';

  final List<String> _times = [
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
  ];

  final List<String> _dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  List<Map<String, String>> _generateDates() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.add(Duration(days: i));
      final dayName = _dayNames[day.weekday - 1];
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return {'dayName': dayName, 'dayNum': '${day.day}', 'dateStr': dateStr};
    });
  }

  final List<Map<String, dynamic>> _wasteOptions = [
    {
      'name': 'General',
      'icon': Icons.delete_outline,
      'color': Color(0xFF757575),
    },
    {'name': 'Recyclable', 'icon': Icons.recycling, 'color': Color(0xFF1565C0)},
    {'name': 'Organic', 'icon': Icons.eco, 'color': Color(0xFF2E7D32)},
    {'name': 'Hazardous', 'icon': Icons.biotech, 'color': Color(0xFFE65100)},
  ];

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: _kCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: _kLightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: _kPrimary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Scheduled!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your pickup has been scheduled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _kTextGray, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dates = _generateDates();

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
          'Schedule Pickup',
          style: TextStyle(
            color: _kTextDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Waste Type
            const Text(
              'Waste Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _wasteOptions.map((w) {
                      final isSelected = selectedWaste == w['name'];
                      final icon = w['icon'] as IconData;
                      final name = w['name'] as String;
                      return GestureDetector(
                        onTap: () => setState(() => selectedWaste = name),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? _kLightGreen : _kCard,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? _kPrimary
                                      : const Color(0xFFBDBDBD),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isSelected ? _kPrimary : _kTextGray,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                name,
                                style: TextStyle(
                                  color: isSelected ? _kPrimary : _kTextGray,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Select Date
            const Text(
              'Select Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    dates.map((d) {
                      final isSelected = selectedDate == d['dateStr'];
                      return GestureDetector(
                        onTap:
                            () => setState(() => selectedDate = d['dateStr']),
                        child: Container(
                          width: 64,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? _kLightGreen : _kCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? _kPrimary
                                      : const Color(0xFFBDBDBD),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                d['dayName']!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? _kPrimary : _kTextGray,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                d['dayNum']!,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? _kPrimary : _kTextDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Preferred Time
            const Text(
              'Preferred Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  _times.map((t) {
                    final isSelected = selectedTime == t;
                    return GestureDetector(
                      onTap: () => setState(() => selectedTime = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? _kPrimary : _kCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isSelected
                                    ? _kPrimary
                                    : const Color(0xFFBDBDBD),
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: isSelected ? Colors.white : _kTextGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),

            const SizedBox(height: 24),

            // Recurring Pickup card
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.refresh, color: _kPrimary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recurring Pickup',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _kTextDark,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Automatically schedule repeat pickups',
                              style: TextStyle(color: _kTextGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isRecurring,
                        onChanged: (val) => setState(() => isRecurring = val),
                        activeThumbColor: _kPrimary,
                      ),
                    ],
                  ),
                  if (isRecurring) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children:
                          ['Weekly', 'Bi-weekly', 'Monthly'].map((f) {
                            final isSel = selectedFrequency == f;
                            return GestureDetector(
                              onTap:
                                  () => setState(() => selectedFrequency = f),
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel ? _kLightGreen : _kBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isSel
                                            ? _kPrimary
                                            : const Color(0xFFBDBDBD),
                                  ),
                                ),
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    color: isSel ? _kPrimary : _kTextGray,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Schedule button
            SizedBox(
              width: double.infinity,
              height: 56,
              child:
                  selectedDate == null
                      ? ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBDBDBD),
                          disabledBackgroundColor: const Color(0xFFBDBDBD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Select a Date First',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      )
                      : ElevatedButton(
                        onPressed: () {
                          provider.addSchedule({
                            'wasteType': selectedWaste,
                            'date': selectedDate,
                            'time': selectedTime,
                            'frequency':
                                isRecurring ? selectedFrequency : 'Once',
                            'isRecurring': isRecurring,
                            'status': 'Active',
                          });
                          _showSuccessDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Schedule Pickup',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

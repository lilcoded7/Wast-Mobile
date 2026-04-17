import 'package:flutter/material.dart';

class SchedulePickupPage extends StatefulWidget {
  const SchedulePickupPage({super.key});

  @override
  State<SchedulePickupPage> createState() => _SchedulePickupPageState();
}

class _SchedulePickupPageState extends State<SchedulePickupPage> {
  String selectedWaste = "General";
  String selectedDate = "26";
  String selectedTime = "09:00";
  bool isRecurring = true;
  String selectedFrequency = "Bi-weekly";

  final List<Map<String, String>> dates = [
    {"day": "Sun", "date": "26"},
    {"day": "Mon", "date": "27"},
    {"day": "Tue", "date": "28"},
    {"day": "Wed", "date": "29"},
    {"day": "Thu", "date": "30"},
    {"day": "Fri", "date": "1"},
  ];

  final List<String> times = [
    "07:00", "08:00", "09:00", "10:00", "11:00",
    "12:00", "13:00", "14:00", "15:00", "16:00",
    "17:00", "18:00"
  ];

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
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
        title: const Text("Schedule Pickup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Waste Type"),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _wasteChip("General", Icons.delete_outline),
                  _wasteChip("Recyclable", Icons.recycling),
                  _wasteChip("Organic", Icons.eco),
                  _wasteChip("Hazardous", Icons.biotech),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _sectionHeader("Select Date"),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: dates.map((d) => _dateChip(d['day']!, d['date']!, accentGreen)).toList(),
              ),
            ),

            const SizedBox(height: 32),
            _sectionHeader("Preferred Time"),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: times.map((t) => _timeChip(t, accentGreen)).toList(),
            ),

            const SizedBox(height: 32),
            _buildRecurringCard(cardColor, accentGreen),

            const SizedBox(height: 24),
            _buildSummaryCard(cardColor, accentGreen),

            const SizedBox(height: 32),
            _buildScheduleButton(accentGreen),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _wasteChip(String label, IconData icon) {
    bool isSelected = selectedWaste == label;
    return GestureDetector(
      onTap: () => setState(() => selectedWaste = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E4D2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? const Color(0xFF5ED5A8) : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF5ED5A8) : Colors.white60),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(String day, String date, Color accent) {
    bool isSelected = selectedDate == date;
    return GestureDetector(
      onTap: () => setState(() => selectedDate = date),
      child: Container(
        width: 65,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A2E1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? accent : Colors.white12),
        ),
        child: Column(
          children: [
            Text(day, style: TextStyle(color: isSelected ? accent : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(date, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(String time, Color accent) {
    bool isSelected = selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accent : Colors.white12),
        ),
        child: Text(
          time,
          style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRecurringCard(Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.refresh, color: Color(0xFF5ED5A8)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Recurring Pickup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("Automatically schedule repeat pickups", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: isRecurring,
                onChanged: (val) => setState(() => isRecurring = val),
                activeColor: accent,
              ),
            ],
          ),
          if (isRecurring) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ["Weekly", "Bi-weekly", "Monthly"].map((f) => _freqChip(f, accent)).toList(),
            )
          ]
        ],
      ),
    );
  }

  Widget _freqChip(String label, Color accent) {
    bool isSelected = selectedFrequency == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFrequency = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E4D2E) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? accent : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? accent : Colors.white38, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildSummaryCard(Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: accent, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Scheduled Pickup", style: TextStyle(color: Color(0xFF5ED5A8), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Sunday 19 April at 09:00 • Repeats $selectedFrequency", style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 8),
                _badge(selectedWaste),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildScheduleButton(Color accent) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: const Text("Schedule Pickup", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
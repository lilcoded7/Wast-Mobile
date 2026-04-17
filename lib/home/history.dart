import 'package:flutter/material.dart';

class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({super.key});

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  String selectedFilter = "All";
  final List<String> filters = [
    "All",
    "Completed",
    "Active",
    "Scheduled",
    "Cancelled",
  ];

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Service History",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "5 requests total",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // 2. HORIZONTAL FILTERS
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children:
                    filters
                        .map((filter) => _buildFilterChip(filter, accentGreen))
                        .toList(),
              ),
            ),

            // 3. HISTORY LIST
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                children: [
                  _historyItem(
                    "Organic",
                    "14 Ring Road East, Accra",
                    "10 Apr 2026",
                    "GH₵ 20",
                    "Pending",
                    Colors.amber,
                    cardColor,
                  ),
                  _historyItem(
                    "General",
                    "Dansoman, Accra",
                    "10 Apr 2026",
                    "GH₵ 20",
                    "Pending",
                    Colors.amber,
                    cardColor,
                  ),
                  _historyItem(
                    "Recyclable",
                    "Tema Community 1, Accra",
                    "10 Apr 2026",
                    "GH₵ 20",
                    "Arrived",
                    accentGreen,
                    cardColor,
                  ),
                  _historyItem(
                    "General",
                    "12 Cantonments Road, Accra",
                    "10 Apr 2026",
                    "GH₵ 20",
                    "Completed",
                    Colors.green,
                    cardColor,
                  ),
                  _historyItem(
                    "Recyclable",
                    "12 Cantonments Road, Accra",
                    "9 Apr 2026",
                    "GH₵ 20",
                    "Completed",
                    Colors.green,
                    cardColor,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Color accent) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _historyItem(
    String type,
    String address,
    String date,
    String price,
    String status,
    Color statusColor,
    Color bg,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_typeBadge(type), _statusBadge(status, statusColor)],
          ),
          const SizedBox(height: 12),
          Text(
            address,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    IconData icon;
    Color color;
    if (type == "Organic") {
      icon = Icons.eco;
      color = const Color(0xFF8BCA3E);
    } else if (type == "Recyclable") {
      icon = Icons.recycling;
      color = Colors.blue;
    } else {
      icon = Icons.delete_outline;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            type,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

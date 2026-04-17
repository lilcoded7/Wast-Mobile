import 'package:flutter/material.dart';

class SchedulePickupPage extends StatefulWidget {
  const SchedulePickupPage({super.key});

  @override
  State<SchedulePickupPage> createState() => _SchedulePickupPageState();
}

class _SchedulePickupPageState extends State<SchedulePickupPage> {
  String _selectedType = "General";
  String _selectedVolume = "Standard Bin";
  final Color primaryColor = Colors.green[700]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Schedule Pickup", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader("1", "Select Waste Type"),
            const SizedBox(height: 16),
            _buildWasteTypeGrid(),
            
            const SizedBox(height: 32),
            _buildStepHeader("2", "Select Volume"),
            const SizedBox(height: 16),
            _buildVolumeSelector(),

            const SizedBox(height: 32),
            _buildStepHeader("3", "Collection Details"),
            const SizedBox(height: 16),
            _buildLocationTile(),

            const SizedBox(height: 40),
            
            // Final Summary & Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Estimated Cost", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("GH₵ 25.00", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to Tracking or show success
                      Navigator.pushNamed(context, '/tracking');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Confirm Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String number, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: primaryColor,
          child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWasteTypeGrid() {
    final types = [
      {"name": "General", "icon": Icons.delete_outline},
      {"name": "Plastic", "icon": Icons.recycling},
      {"name": "Organic", "icon": Icons.eco_outlined},
      {"name": "E-Waste", "icon": Icons.computer},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: types.map((type) {
        bool isSelected = _selectedType == type['name'];
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type['name'] as String),
          child: Container(
            width: (MediaQuery.of(context).size.width - 60) / 2,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? primaryColor : Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(type['icon'] as IconData, color: isSelected ? Colors.white : primaryColor),
                const SizedBox(width: 12),
                Text(type['name'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVolumeSelector() {
    final volumes = ["Small Bag", "Standard Bin", "Large Load"];
    return Row(
      children: volumes.map((v) {
        bool isSelected = _selectedVolume == v;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedVolume = v),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? primaryColor : Colors.grey[200]!),
              ),
              child: Center(
                child: Text(v, style: TextStyle(color: isSelected ? primaryColor : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.redAccent),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pickup Address", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("24 Crescent St, Accra", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
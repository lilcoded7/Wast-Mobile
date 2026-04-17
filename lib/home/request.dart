import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String selectedType = "general";
  String address = "12 Cantonments Road, Accra";

  final List<Map<String, dynamic>> wasteTypes = [
    {"type": "general", "label": "General Waste", "price": 20, "icon": Icons.delete_outline},
    {"type": "recyclable", "label": "Recyclable", "price": 20, "icon": Icons.recycling},
    {"type": "hazardous", "label": "Hazardous", "price": 45, "icon": Icons.warning_amber},
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF16a34a);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Request Pickup", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("Waste Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...wasteTypes.map((w) => _buildTypeCard(w, primaryColor)),
                const SizedBox(height: 24),
                const Text("Pickup Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildAddressBar(primaryColor),
              ],
            ),
          ),
          _buildBottomNav(primaryColor),
        ],
      ),
    );
  }

  Widget _buildTypeCard(Map<String, dynamic> w, Color primary) {
    bool active = selectedType == w['type'];
    return GestureDetector(
      onTap: () {
        setState(() => selectedType = w['type']);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? primary : Colors.grey[200]!, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(w['icon'], color: active ? primary : Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(w['label'], style: TextStyle(fontWeight: FontWeight.bold, color: active ? primary : Colors.black))),
            Text("GH₵${w['price']}"),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressBar(Color primary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Icon(Icons.location_on, color: primary, size: 20),
          const SizedBox(width: 10),
          Text(address, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(Color primary) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            // Navigation to Confirm/Tracking logic
          },
          child: const Text("Continue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
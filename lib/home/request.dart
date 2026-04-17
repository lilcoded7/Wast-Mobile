import 'package:flutter/material.dart';
import 'dart:async';

class RequestPickupPage extends StatefulWidget {
  const RequestPickupPage({super.key});

  @override
  State<RequestPickupPage> createState() => _RequestPickupPageState();
}

class _RequestPickupPageState extends State<RequestPickupPage> {
  // State 0: Form, State 1: Finding, State 2: Found
  int currentStep = 0; 
  String selectedWaste = "General Waste";

  void _handleSubmit() {
    setState(() => currentStep = 1);
    // Simulate finding a collector after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => currentStep = 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);

    return Scaffold(
      backgroundColor: bgColor,
      body: _buildCurrentState(bgColor, cardColor, accentGreen),
    );
  }

  Widget _buildCurrentState(Color bg, Color card, Color accent) {
    if (currentStep == 0) return _buildRequestForm(bg, card, accent);
    if (currentStep == 1) return _buildFindingCollector(bg, card, accent);
    return _buildCollectorFound(bg, card, accent);
  }

  // --- STEP 1: THE FORM ---
  Widget _buildRequestForm(Color bg, Color card, Color accent) {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: const Text("Request Pickup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _infoBanner(accent),
              const SizedBox(height: 24),
              const Text("Waste Type", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _wasteItem("General Waste", "Household and everyday...", "GH₵ 20", Icons.delete_outline, card, accent),
              _wasteItem("Recyclable", "Paper, plastic, glass, metal", "GH₵ 20", Icons.recycling, card, accent),
              _wasteItem("Organic / Compost", "Food scraps and garden waste", "GH₵ 20", Icons.eco, card, accent),
              _wasteItem("Hazardous", "Chemicals, batteries, e-waste", "GH₵ 45", Icons.biotech, card, accent),
              const SizedBox(height: 24),
              const Text("Pickup Location", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _locationField(card),
              const SizedBox(height: 24),
              const Text("Notes (optional)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _notesField(card),
              const SizedBox(height: 40),
            ],
          ),
        ),
        _bottomStickyBar(accent),
      ],
    );
  }

  // --- STEP 2: FINDING COLLECTOR ---
  Widget _buildFindingCollector(Color bg, Color card, Color accent) {
    return Stack(
      children: [
        // Placeholder for Map Background
        Container(color: const Color(0xFF1A2E1A)), 
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFF2E4D2E),
                child: Icon(Icons.local_shipping, color: Color(0xFF5ED5A8), size: 40),
              ),
              const SizedBox(height: 24),
              const Text("Finding a collector...", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("We are matching you with the nearest available collector", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Color(0xFF5ED5A8)),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => setState(() => currentStep = 0),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Cancel Request", style: TextStyle(color: Colors.white70)),
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  // --- STEP 3: COLLECTOR INFO ---
  Widget _buildCollectorFound(Color bg, Color card, Color accent) {
    return Stack(
      children: [
        Container(color: const Color(0xFF1A2E1A)), // Map background
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: card, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 30, backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("John Doe", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Waste Collector • 4.9 ★", style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                    _actionBtn(Icons.phone, accent),
                    const SizedBox(width: 10),
                    _actionBtn(Icons.chat_bubble_outline, accent),
                  ],
                ),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Est. Arrival", style: TextStyle(color: Colors.white54)),
                    Text("5 - 8 mins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Confirm Pickup", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  // --- WIDGET HELPERS ---

  Widget _infoBanner(Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text("You have an active request. Tap to track it.", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13))),
          Icon(Icons.chevron_right, color: accent, size: 20),
        ],
      ),
    );
  }

  Widget _wasteItem(String title, String sub, String price, IconData icon, Color bg, Color accent) {
    bool isSelected = selectedWaste == title;
    return GestureDetector(
      onTap: () => setState(() => selectedWaste = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? accent : Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: isSelected ? accent : Colors.white38)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                if (isSelected) Icon(Icons.check_circle, color: accent, size: 20),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _locationField(Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          Icon(Icons.location_on_outlined, color: Color(0xFF5ED5A8)),
          SizedBox(width: 16),
          Text("12 Cantonments Road, Accra", style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _notesField(Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: const TextField(
        maxLines: 3,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(hintText: "Add any special instructions...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
      ),
    );
  }

  Widget _bottomStickyBar(Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Color(0xFF0D1B0D), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Row(
        children: [
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total", style: TextStyle(color: Colors.white38, fontSize: 12)),
              Text("GH₵ 20", style: TextStyle(color: Color(0xFF5ED5A8), fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Continue", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.black, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}
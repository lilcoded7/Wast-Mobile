import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tracking_page.dart'; 

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF142414);
    const Color accentGreen = Color(0xFF5ED5A8);
    const Color organicColor = Color(0xFF8BCA3E);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. BACKGROUND MAP LAYER (Placeholder)
          Positioned.fill(
            child: Container(
              color: const Color(0xFFD4E7D4),
              child: Opacity(
                opacity: 0.2,
                child: GridPaper(
                  color: Colors.green.withOpacity(0.2),
                  divisions: 1,
                  subdivisions: 1,
                ),
              ),
            ),
          ),

          // 2. SCROLLABLE CONTENT LAYER
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP BAR ---
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Good morning,",
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16)),
                            const Text("Kwame",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_outlined,
                                  color: Colors.white),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Color(0xFFE57373),
                                    shape: BoxShape.circle),
                                child: const Text("10",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- ACTIVE REQUEST CARD ---
                  const Text("Active Request",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBadge("Organic", organicColor, Icons.eco),
                            
                            // LINKED TRACK COMMAND
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const TrackingPage()),
                                );
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                        color: accentGreen,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.near_me,
                                        color: Colors.black, size: 20),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text("Track",
                                      style: TextStyle(
                                          color: accentGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
                        const Text("14 Ring Road East, Accra",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildStatusBadge("Pending", const Color(0xFFFFC107)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time,
                                  color: accentGreen, size: 18),
                              const SizedBox(width: 8),
                              const Text("ETA: 10-15 min",
                                  style: TextStyle(
                                      color: accentGreen,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  // --- QUICK ACTIONS ---
                  const SizedBox(height: 24),
                  const Text("Quick Actions",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionBtn("Request\nPickup", Icons.delete_outline, cardColor),
                      _buildActionBtn("Schedule", Icons.calendar_today_outlined, cardColor),
                      _buildActionBtn("Report\nDump", Icons.error_outline, cardColor),
                      _buildActionBtn("History", Icons.history, cardColor),
                    ],
                  ),

                  // --- WASTE TYPES ---
                  const SizedBox(height: 24),
                  const Text("Waste Types",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildWasteTypeCard("General", "GH₵ 20", Icons.delete,
                            Colors.grey, cardColor),
                        _buildWasteTypeCard("Recyclable", "GH₵ 20",
                            Icons.recycling, Colors.blue, cardColor),
                        _buildWasteTypeCard("Organic", "GH₵ 20", Icons.eco,
                            organicColor, cardColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(bgColor),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color) {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7)),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWasteTypeCard(
      String title, String price, IconData icon, Color accent, Color cardBg) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      width: 140,
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(title, accent, icon),
          const SizedBox(height: 12),
          Text(price,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(Color bgColor) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_filled, "Home", true),
          _navItem(Icons.history, "History", false),
          _navItem(Icons.person_outline, "Profile", false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon,
            color: isActive ? const Color(0xFF5ED5A8) : Colors.grey, size: 28),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: isActive ? const Color(0xFF5ED5A8) : Colors.grey,
                fontSize: 12)),
      ],
    );
  }
}
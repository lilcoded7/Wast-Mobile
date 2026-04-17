import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Exact color palette from the reference
    const Color bgColor = Color(0xFF061405); // Deep dark green/black
    const Color cardColor = Color(0xFF132314); // Dark forest card
    const Color accentGreen = Color(0xFF5ED5A8); // Track button green
    const Color organicGreen = Color(0xFF8BCA3E); // Badge green
    const Color glassBorder = Color(0xFF2D3C2D); // Subtle border

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. DYNAMIC MAP BACKGROUND
          // In a real app, replace this Container with GoogleMap()
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFD4E7D4), // Light map base
              ),
              child: Opacity(
                opacity: 0.3,
                child: GridPaper(
                  color: Colors.green.withOpacity(0.3),
                  divisions: 1,
                  subdivisions: 1,
                  interval: 100,
                ),
              ),
            ),
          ),
          
          // MAP OVERLAY GRADIENT (Creates the "fade" into the dark UI)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    bgColor.withOpacity(0.8),
                    bgColor,
                  ],
                  stops: const [0.0, 0.4, 0.7],
                ),
              ),
            ),
          ),

          // 2. SCROLLABLE CONTENT
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // POLISHED TOP BAR
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Good morning,",
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 18,
                                    letterSpacing: 0.5)),
                            const Text("Kwame",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                        _buildNotificationBell(),
                      ],
                    ),
                  ),
                ),

                // CONTENT SECTION
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text("Active Request",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      
                      // POLISHED ACTIVE REQUEST CARD
                      _buildActiveRequestCard(cardColor, organicGreen, accentGreen),

                      const SizedBox(height: 32),
                      const Text("Quick Actions",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      
                      // POLISHED QUICK ACTIONS GRID
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildActionBtn("Request\nPickup", Icons.delete_outline, cardColor, const Color(0xFF4CAF50)),
                          _buildActionBtn("Schedule", Icons.calendar_month_outlined, cardColor, const Color(0xFF2196F3)),
                          _buildActionBtn("Report\nDump", Icons.report_problem_outlined, cardColor, const Color(0xFFF44336)),
                          _buildActionBtn("History", Icons.history_outlined, cardColor, Colors.white70),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Text("Waste Types",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      
                      // HORIZONTAL WASTE TYPES
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildWasteTypeCard("General", "GH₵ 20", Icons.delete_sweep, Colors.grey.shade400, cardColor),
                            _buildWasteTypeCard("Recyclable", "GH₵ 20", Icons.recycling_rounded, Colors.lightBlueAccent, cardColor),
                            _buildWasteTypeCard("Organic", "GH₵ 20", Icons.eco_rounded, organicGreen, cardColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 120),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(bgColor, accentGreen),
    );
  }

  // --- POLISHED UI COMPONENTS ---

  Widget _buildNotificationBell() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Color(0xFFE57373), shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: const Text("10",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  Widget _buildActiveRequestCard(Color cardBg, Color organic, Color trackColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge("Organic", organic, Icons.eco),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Color(0xFF5ED5A8), shape: BoxShape.circle),
                    child: const Icon(Icons.near_me_rounded, color: Colors.black, size: 22),
                  ),
                  const SizedBox(height: 6),
                  const Text("Track", style: TextStyle(color: Color(0xFF5ED5A8), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const Text("14 Ring Road East, Accra",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildStatusBadge("Pending", const Color(0xFFFFC107)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05))),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFF5ED5A8), size: 20),
                const SizedBox(width: 10),
                const Text("ETA: 10-15 min",
                    style: TextStyle(color: Color(0xFF5ED5A8), fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color bg, Color iconColor) {
    return Container(
      width: 82,
      height: 105,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 10),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildWasteTypeCard(String title, String price, IconData icon, Color accent, Color bg) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(18),
      width: 150,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(title, accent, icon),
          const SizedBox(height: 16),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Row(
            children: [
              Container(height: 6, width: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(Color bg, Color active) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 25),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_filled, "Home", true, active),
          _navItem(Icons.history_rounded, "History", false, active),
          _navItem(Icons.person_2_outlined, "Profile", false, active),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive, Color activeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? activeColor : Colors.white38, size: 28),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? activeColor : Colors.white38, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);
    const Color headerGreen = Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. STICKY/FLEXIBLE HEADER
          SliverAppBar(
            expandedHeight: 280,
            backgroundColor: bgColor,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: headerGreen,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(45)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildProfileImage(bgColor, headerGreen),
                    const SizedBox(height: 16),
                    const Text(
                      "Kwame Asante",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "lilcoded7@gmail.com • +233 24 000 0000",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Floating Edit Button
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 10),
                child: IconButton(
                  onPressed: () => HapticFeedback.lightImpact(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),

          // 2. SCROLLABLE CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 100), // Large bottom padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel("ACCOUNT"),
                  _buildGroupedCard(cardColor, [
                    _buildTile(Icons.map_outlined, "Saved Addresses", accentGreen, trailing: _buildBadge("2")),
                    _buildTile(Icons.wallet_outlined, "Payment Methods", accentGreen),
                    _buildTile(Icons.notifications_none_rounded, "Notifications", accentGreen),
                  ]),

                  const SizedBox(height: 30),
                  _buildSectionLabel("ACTIVITY"),
                  _buildGroupedCard(cardColor, [
                    _buildTile(Icons.receipt_long_outlined, "Service History", accentGreen),
                    _buildTile(Icons.campaign_outlined, "Dumping Reports", accentGreen),
                  ]),

                  const SizedBox(height: 30),
                  _buildSectionLabel("SUPPORT"),
                  _buildGroupedCard(cardColor, [
                    _buildTile(Icons.help_center_outlined, "Help & Support", accentGreen),
                    _buildTile(Icons.star_border_rounded, "Rate the App", accentGreen),
                    _buildTile(Icons.info_outline_rounded, "About", accentGreen),
                  ]),

                  const SizedBox(height: 50),
                  
                  // LOGOUT AT THE VERY BOTTOM
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildProfileImage(Color bg, Color header) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: const CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            child: Text(
              "K",
              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 45, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => HapticFeedback.mediumImpact(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: header, width: 3),
            ),
            child: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildGroupedCard(Color bg, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile(IconData icon, String title, Color accent, {Widget? trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 16),
      onTap: () {
        HapticFeedback.selectionClick();
      },
    );
  }

  Widget _buildBadge(String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF5ED5A8).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count,
        style: const TextStyle(color: Color(0xFF5ED5A8), fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: InkWell(
        onTap: () {
          HapticFeedback.heavyImpact();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text(
                "Sign Out",
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wastmobile/providers/user_provider.dart';

// Feature Imports - Mapped to your actual folder structure
import '../auth/login.dart';
import 'history.dart';
import 'notification.dart'; // Fixed: was notifications.dart
import 'saved_address.dart'; // Fixed: was saved_addresses.dart
import 'reports.dart'; // Fixed: contains DumpingReportsPage
import 'payment.dart'; // Fixed: was payment_methods.dart

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.authData?['user'];

    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);
    const Color headerGreen = Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            backgroundColor: bgColor,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: headerGreen,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(45),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildProfileImage(bgColor, headerGreen),
                    const SizedBox(height: 16),
                    Text(
                      user?['username'] ?? "User",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "${user?['email'] ?? ''} • ${user?['phone_number'] ?? ''}",
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel("ACCOUNT"),
                  _buildGroupedCard(cardColor, [
                    _buildTile(
                      context,
                      Icons.map_outlined,
                      "Saved Addresses",
                      accentGreen,
                      // Pointing to the class in saved_address.dart
                      destination: const SavedAddressesPage(),
                    ),
                    _buildTile(
                      context,
                      Icons.wallet_outlined,
                      "Payment Methods",
                      accentGreen,
                      // Pointing to the class in payment.dart
                      destination: const PaymentMethodsPage(),
                    ),
                    _buildTile(
                      context,
                      Icons.notifications_none_rounded,
                      "Notifications",
                      accentGreen,
                      // Pointing to the class in notification.dart
                      destination: const NotificationPage(),
                    ),
                  ]),
                  const SizedBox(height: 30),
                  _buildSectionLabel("ACTIVITY"),
                  _buildGroupedCard(cardColor, [
                    _buildTile(
                      context,
                      Icons.receipt_long_outlined,
                      "Service History",
                      accentGreen,
                      // Pointing to history.dart
                      destination: const ServiceHistoryPage(),
                    ),
                    _buildTile(
                      context,
                      Icons.campaign_outlined,
                      "Dumping Reports",
                      accentGreen,
                      // Pointing to report_dumping.dart
                      destination: const DumpingReportsPage(),
                    ),
                  ]),
                  const SizedBox(height: 30),
                  _buildSectionLabel("SUPPORT"),
                  _buildGroupedCard(cardColor, [
                    _buildTile(
                      context,
                      Icons.help_center_outlined,
                      "Help & Support",
                      accentGreen,
                    ),
                    _buildTile(
                      context,
                      Icons.info_outline_rounded,
                      "About",
                      accentGreen,
                    ),
                  ]),
                  const SizedBox(height: 50),
                  _buildLogoutButton(context),
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
    return Container(
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
          style: TextStyle(
            color: Color(0xFF4CAF50),
            fontSize: 45,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white30,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
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

  Widget _buildTile(
    BuildContext context,
    IconData icon,
    String title,
    Color accent, {
    Widget? trailing,
    Widget? destination,
  }) {
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing:
          trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white12,
            size: 16,
          ),
      onTap: () {
        HapticFeedback.selectionClick();
        if (destination != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        }
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: () {
          HapticFeedback.heavyImpact();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
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
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

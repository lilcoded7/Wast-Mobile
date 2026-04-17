import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Account"), backgroundColor: Colors.white, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // User Details
          const Center(
            child: Column(
              children: [
                CircleAvatar(radius: 40, backgroundColor: Colors.green, child: Icon(Icons.person, color: Colors.white, size: 40)),
                SizedBox(height: 12),
                Text("lilcoded7", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("user@example.com", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Ghana Specific Wallet Settings
          const Text("Financials", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          _profileTile(Icons.account_balance_wallet, "Wallet (GH₵ 45.50)", () {}),
          _profileTile(Icons.phonelink_setup, "Linked MoMo Number", () {
             // Logic to show: 0240000053
          }),
          
          const SizedBox(height: 24),
          const Text("Preferences", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          _profileTile(Icons.location_on_outlined, "Pickup Address", () {}),
          _profileTile(Icons.notifications_outlined, "Alerts", () {}),
          
          const SizedBox(height: 32),
          ListTile(
            onTap: () => Navigator.pushReplacementNamed(context, '/'),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      contentPadding: EdgeInsets.zero,
    );
  }
}
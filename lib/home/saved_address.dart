import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  List<dynamic> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.authData?['access'];

    const String url = "http://127.0.0.1:8000/api/v2/wast/saved/address/";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _addresses = data['results'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching addresses: $e");
    }
  }

  void _showAddressOptions(Map<String, dynamic> item, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF132314),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['address'] ?? 'Saved Address',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Coordinates: ${item['latitude']}, ${item['longitude']}",
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.directions, color: accent),
              title: const Text("Use this Address", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text("Remove Address", style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

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
        title: const Text("Saved Addresses", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGreen))
          : RefreshIndicator(
              onRefresh: _fetchAddresses,
              child: _addresses.isEmpty
                  ? const Center(child: Text("No saved addresses", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _addresses.length,
                      itemBuilder: (context, index) {
                        final item = _addresses[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: ListTile(
                            onTap: () => _showAddressOptions(item, accentGreen),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on, color: accentGreen, size: 20),
                            ),
                            title: Text(
                              item['address'] ?? 'Unnamed Location',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${item['distance_km']} km away",
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                            trailing: const Icon(Icons.more_vert, color: Colors.white38),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentGreen,
        onPressed: () { /* Future: Logic to add new address */ },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
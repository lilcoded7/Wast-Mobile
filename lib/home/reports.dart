import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';

class DumpingReportsPage extends StatefulWidget {
  const DumpingReportsPage({super.key});

  @override
  State<DumpingReportsPage> createState() => _DumpingReportsPageState();
}

class _DumpingReportsPageState extends State<DumpingReportsPage> {
  List<dynamic> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.authData?['access'];

    const String url = "http://127.0.0.1:8000/api/v2/wast/reports/dumping/";

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
          _reports = data['results'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error: $e");
    }
  }

  // DETAILED REPORT VIEW MODAL
  void _viewReportDetails(Map<String, dynamic> report, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF132314),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  report['photo'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(height: 200, color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(report['town_or_city']?.toUpperCase() ?? "UNKNOWN", style: TextStyle(color: accent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  _buildStatusChip(report['is_investigated']),
                ],
              ),
              const SizedBox(height: 12),
              Text(report['address'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text("DESCRIPTION", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(report['description'], style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
              const SizedBox(height: 24),
              if (report['admin_notes'] != null) ...[
                const Text("ADMIN NOTES", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: Text(report['admin_notes'], style: const TextStyle(color: Colors.amber, fontStyle: FontStyle.italic)),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool investigated) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: investigated ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: investigated ? Colors.green : Colors.amber, width: 0.5),
      ),
      child: Text(
        investigated ? "INVESTIGATED" : "PENDING",
        style: TextStyle(color: investigated ? Colors.green : Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("Dumping Reports", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGreen))
          : RefreshIndicator(
              onRefresh: _fetchReports,
              child: _reports.isEmpty
                  ? const Center(child: Text("No reports submitted yet", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final item = _reports[index];
                        DateTime dt = DateTime.parse(item['created_at']);
                        return GestureDetector(
                          onTap: () => _viewReportDetails(item, accentGreen),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                  child: Image.network(
                                    item['photo'],
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, e, s) => Container(height: 150, color: Colors.white10, child: const Icon(Icons.image_not_supported, color: Colors.white24)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(DateFormat('dd MMM yyyy').format(dt), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                                          _buildStatusChip(item['is_investigated']),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(item['address'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(item['town_or_city'], style: TextStyle(color: accentGreen.withOpacity(0.7), fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
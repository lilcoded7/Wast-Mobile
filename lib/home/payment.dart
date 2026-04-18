import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.authData?['access'];

    const String url = "http://127.0.0.1:8000/api/v2/wast/user/payment/";

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
          _payments = data['results'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching payments: $e");
    }
  }

  // Helper to mask numbers for security (e.g., **** 9843 or 050****441)
  String _maskNumber(String? number, bool isCard) {
    if (number == null || number.isEmpty) return "No details";
    if (isCard) {
      return "**** **** **** ${number.length > 4 ? number.substring(number.length - 4) : number}";
    }
    return "${number.substring(0, 3)} **** ${number.substring(number.length - 3)}";
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
        title: const Text(
          "Payment Methods",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGreen))
          : RefreshIndicator(
              onRefresh: _fetchPayments,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _payments.length + 1, // +1 for the "Add" button
                itemBuilder: (context, index) {
                  if (index == _payments.length) {
                    return _buildAddButton(accentGreen);
                  }

                  final item = _payments[index];
                  bool isCard = item['account_type'] == 'card';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCard ? Icons.credit_card : Icons.account_balance_wallet,
                            color: accentGreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name_or_card_name'] ?? "Payment Method",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isCard 
                                  ? _maskNumber(item['card_number'], true)
                                  : _maskNumber(item['account_number'], false),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white38),
                          color: cardColor,
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              child: Text("Set as Default", style: TextStyle(color: Colors.white)),
                            ),
                            const PopupMenuItem(
                              child: Text("Remove", style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildAddButton(Color accent) {
    return InkWell(
      onTap: () { /* Navigate to Add Payment Page */ },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.3), style: BorderStyle.none), // Can use dotted border if needed
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: accent),
            const SizedBox(width: 12),
            Text(
              "Add New Payment Method",
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
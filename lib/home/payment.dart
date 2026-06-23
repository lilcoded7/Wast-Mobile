import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

const Color _kBg        = Color(0xFFF0F7F0);
const Color _kPrimary   = Color(0xFF2E7D32);
const Color _kCard      = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark  = Color(0xFF1A1A1A);
const Color _kTextGray  = Color(0xFF757575);

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppProvider>().fetchPaymentMethods();
      if (mounted) setState(() => _loading = false);
    });
  }

  // ── Add payment method bottom sheet ────────────────────────────────────────
  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPaymentSheet(
        onSave: (type, details) async {
          Navigator.pop(context);
          try {
            await context.read<AppProvider>().addPaymentMethod({
              'type': type,
              ...details,
            });
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _delete(dynamic id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove payment method?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: const Text(
            'This payment method will be removed from your account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: _kTextGray))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child:
                const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppProvider>().deletePaymentMethod(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final methods = provider.paymentMethods;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Payment Methods',
            style: TextStyle(
                color: _kTextDark, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: _kPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Method',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : methods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.credit_card_off_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No payment methods saved',
                          style:
                              TextStyle(color: _kTextGray, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text(
                          'Add your MoMo number for faster checkout',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kTextGray, fontSize: 13)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showAddSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add Payment Method',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: methods.length,
                  itemBuilder: (context, index) {
                    final item = methods[index];
                    final isDefault = item['isDefault'] == true;
                    final type = (item['type'] as String?) ?? '';
                    final number = (item['number'] as String?) ?? '';
                    final icon = _iconFor(type);
                    final color = _colorFor(type);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: isDefault
                            ? Border.all(color: _kPrimary, width: 1.5)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        title: Text(type,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _kTextDark)),
                        subtitle: number.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(number,
                                    style: const TextStyle(
                                        color: _kTextGray, fontSize: 13)),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kLightGreen,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _kPrimary),
                                ),
                                child: const Text('Default',
                                    style: TextStyle(
                                        color: _kPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 22),
                              onPressed: () => _delete(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _iconFor(String type) {
    if (type.toLowerCase().contains('momo') ||
        type.toLowerCase().contains('mobile')) {
      return Icons.phone_android;
    }
    if (type.toLowerCase().contains('card') ||
        type.toLowerCase().contains('credit') ||
        type.toLowerCase().contains('debit')) {
      return Icons.credit_card;
    }
    return Icons.payments_outlined;
  }

  Color _colorFor(String type) {
    if (type.toLowerCase().contains('momo') ||
        type.toLowerCase().contains('mobile')) {
      return const Color(0xFFFF6F00);
    }
    if (type.toLowerCase().contains('card')) return const Color(0xFF1565C0);
    return _kPrimary;
  }
}

// ── Add payment sheet ──────────────────────────────────────────────────────────
class _AddPaymentSheet extends StatefulWidget {
  final void Function(String type, Map<String, dynamic> details) onSave;
  const _AddPaymentSheet({required this.onSave});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  String _provider = 'MTN';
  final _numCtrl = TextEditingController();

  static const _providers = ['MTN', 'Vodafone', 'AirtelTigo'];

  @override
  void dispose() {
    _numCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Add Mobile Money',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark)),
            const SizedBox(height: 20),
            const Text('Network',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _kTextDark)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _provider,
                  isExpanded: true,
                  style: const TextStyle(color: _kTextDark, fontSize: 15),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (v) => setState(() => _provider = v!),
                  items: _providers
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('MoMo Number',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _kTextDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _numCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '0552779311',
                hintStyle: const TextStyle(color: _kTextGray),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _kPrimary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave('Mobile Money (MoMo)', {
                    'provider': _provider,
                    'number': _numCtrl.text.trim(),
                    'isDefault': false,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Save MoMo Number',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

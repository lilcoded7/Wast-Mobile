import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

const Color _kPrimary    = Color(0xFF2E7D32);
const Color _kDark       = Color(0xFF1B5E20);
const Color _kBg         = Color(0xFFF0F7F0);
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark   = Color(0xFF1A1A1A);
const Color _kTextGray   = Color(0xFF757575);
const Color _kOrange     = Color(0xFFF57C00);

class CollectorPaymentWithdrawalPage extends StatefulWidget {
  const CollectorPaymentWithdrawalPage({super.key});

  @override
  State<CollectorPaymentWithdrawalPage> createState() =>
      _CollectorPaymentWithdrawalPageState();
}

class _CollectorPaymentWithdrawalPageState
    extends State<CollectorPaymentWithdrawalPage> {
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      p.fetchCollectorEarnings();
      p.fetchCollectorCollections();
      p.fetchCollectorPaymentMethods();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p           = context.watch<AppProvider>();
    final balance     = p.accountBalance;
    final commission  = p.unpaidCommission;
    final transactions = p.recentTransactions;

    final filtered = _filter == 'All'
        ? transactions
        : transactions.where((t) {
            final desc = (t['description'] as String? ?? '').toLowerCase();
            if (_filter == 'Cash') return desc.contains('cash');
            return !desc.contains('cash');
          }).toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text('Payment & Withdrawal',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: _kPrimary,
        onRefresh: () async {
          final p = context.read<AppProvider>();
          await p.fetchCollectorEarnings();
          await p.fetchCollectorPaymentMethods();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Balance card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Balance',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    'GH₵ ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleWithdraw(context, balance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.account_balance_wallet, size: 18),
                      label: const Text('Withdraw Funds',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Commission owed card (shown only when owed > 0) ───────────
            if (commission > 0) ...[
              _CommissionInfoCard(amount: commission),
              const SizedBox(height: 14),
            ],

            // ── Wallets ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Withdrawal wallets',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kTextDark)),
                TextButton(
                  onPressed: () => _showAddWallet(context),
                  child: const Text('+ Add MoMo / Bank', style: TextStyle(color: _kPrimary)),
                ),
              ],
            ),
            if (p.collectorPaymentMethods.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Add a MoMo or bank account before withdrawing.',
                    style: TextStyle(color: _kTextGray, fontSize: 12)),
              )
            else
              ...p.collectorPaymentMethods.map((m) {
                final type = m['payment_type'] as String? ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    type == 'bank' ? Icons.account_balance : Icons.phone_android,
                    color: _kPrimary,
                  ),
                  title: Text('${m['provider']} ${m['number']}'),
                  subtitle: Text(type == 'bank' ? 'Bank' : 'Mobile Money'),
                );
              }),
            const SizedBox(height: 8),

            // ── Earnings stats ────────────────────────────────────────────
            Row(
              children: [
                _MiniStat(
                    label: 'Today',
                    value: 'GH₵ ${p.todayEarnings.toStringAsFixed(2)}',
                    icon: Icons.today,
                    color: _kPrimary),
                const SizedBox(width: 10),
                _MiniStat(
                    label: 'This Week',
                    value: 'GH₵ ${p.weeklyEarnings.toStringAsFixed(2)}',
                    icon: Icons.date_range,
                    color: const Color(0xFF1565C0)),
              ],
            ),

            const SizedBox(height: 20),

            // ── Transactions ──────────────────────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text('Transactions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _kTextDark)),
                ),
                Text('${filtered.length} records',
                    style: const TextStyle(
                        color: _kTextGray, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Cash', 'MoMo/Card'].map((f) {
                  final selected = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? _kPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _kPrimary : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Text(f,
                          style: TextStyle(
                              color: selected ? Colors.white : _kTextGray,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text('No transactions found',
                          style: TextStyle(color: _kTextGray)),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((t) => _ApiTransactionTile(item: t)),
          ],
        ),
      ),
    );
  }

  void _handleWithdraw(BuildContext context, double balance) {
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No balance available to withdraw'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (context.read<AppProvider>().collectorPaymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a MoMo or bank wallet first'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    _showWithdrawSheet(context, balance);
  }

  void _showAddWallet(BuildContext context) {
    final typeCtrl = ValueNotifier<String>('mobile_money');
    final numberCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add withdrawal wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: typeCtrl,
              builder: (_, type, __) => Row(
                children: [
                  ChoiceChip(label: const Text('MoMo'), selected: type == 'mobile_money', onSelected: (_) => typeCtrl.value = 'mobile_money'),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Bank'), selected: type == 'bank', onSelected: (_) => typeCtrl.value = 'bank'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: providerCtrl, decoration: const InputDecoration(labelText: 'Provider / Bank name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'Number / Account', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await context.read<AppProvider>().addCollectorPaymentMethod(
                      paymentType: typeCtrl.value,
                      number: numberCtrl.text.trim(),
                      provider: providerCtrl.text.trim(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wallet added'), backgroundColor: _kPrimary),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                child: const Text('Save wallet', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context, double balance) {
    final p = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _WithdrawSheet(
        balance: balance,
        commission: p.unpaidCommission,
        paymentMethods: p.collectorPaymentMethods,
        onConfirm: (amount, methodId) async {
          Navigator.pop(ctx);
          try {
            final msg = await context.read<AppProvider>().requestWithdrawal(amount, paymentMethodId: methodId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: _kPrimary, behavior: SnackBarBehavior.floating),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Commission info (auto-settled on withdraw) ────────────────────────────────
class _CommissionInfoCard extends StatelessWidget {
  final double amount;
  const _CommissionInfoCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _kOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You owe GH₵ ${amount.toStringAsFixed(2)} commission on cash collections. '
              'This is deducted automatically when you withdraw.',
              style: const TextStyle(color: Color(0xFF7B4C00), fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini stat card ─────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _kTextGray, fontSize: 11)),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────
class _ApiTransactionTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ApiTransactionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as String? ?? '';
    final isDebit = type == 'commission';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isDebit ? Icons.remove_circle_outline : Icons.add_circle_outline,
              color: isDebit ? Colors.red : _kPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['description'] as String? ?? type,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kTextDark)),
                Text(item['date'] as String? ?? '',
                    style: const TextStyle(color: _kTextGray, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${isDebit ? '-' : '+'}GH₵ ${(item['amount'] as num?)?.toStringAsFixed(2) ?? '0'}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDebit ? Colors.red : _kPrimary),
          ),
        ],
      ),
    );
  }
}

// ── Withdraw sheet ─────────────────────────────────────────────────────────────
class _WithdrawSheet extends StatefulWidget {
  final double balance;
  final double commission;
  final List<Map<String, dynamic>> paymentMethods;
  final Future<void> Function(double amount, int methodId) onConfirm;
  const _WithdrawSheet({
    required this.balance,
    required this.commission,
    required this.paymentMethods,
    required this.onConfirm,
  });

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  bool _processing = false;
  int? _selectedMethodId;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethods.isNotEmpty) {
      _selectedMethodId = widget.paymentMethods.first['id'] as int?;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_selectedMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a wallet'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _processing = true);
    await widget.onConfirm(amount, _selectedMethodId!);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Withdraw Funds',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextDark)),
          Text('Available: GH₵ ${widget.balance.toStringAsFixed(2)}',
              style: const TextStyle(color: _kTextGray, fontSize: 13)),
          if (widget.commission > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Commission debt GH₵ ${widget.commission.toStringAsFixed(2)} will be deducted first.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          _SheetField(
            ctrl: _amountCtrl,
            label: 'Amount (GH₵)',
            hint: '0.00',
            icon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          Wrap(
            spacing: 8,
            children: [20, 50, 100, 200].map((v) => ActionChip(
              label: Text('GH₵ $v'),
              onPressed: () => _amountCtrl.text = v.toString(),
            )).toList(),
          ),
          const SizedBox(height: 12),
          const Text('Withdraw to', style: TextStyle(fontWeight: FontWeight.w600)),
          ...widget.paymentMethods.map((m) {
            final id = m['id'] as int;
            final type = m['payment_type'] as String? ?? '';
            return RadioListTile<int>(
              value: id,
              groupValue: _selectedMethodId,
              onChanged: (v) => setState(() => _selectedMethodId = v),
              title: Text('${m['provider']} ${m['number']}'),
              subtitle: Text(type == 'bank' ? 'Bank' : 'MoMo'),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _processing ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, elevation: 0),
              child: _processing
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Withdrawal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _SheetField({
    required this.ctrl, required this.label,
    required this.hint, required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _kTextDark)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kTextGray),
            prefixIcon: Icon(icon, size: 20, color: _kTextGray),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

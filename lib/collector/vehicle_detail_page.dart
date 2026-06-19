import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import '../services/api_service.dart';

const Color _kPrimary = Color(0xFF2E7D32);
const Color _kBg = Color(0xFFF0F7F0);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

class VehicleDetailPage extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailPage({super.key, required this.vehicleId});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get(ApiConstants.collectorVehicleDetail(widget.vehicleId));
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final driver = d?['driver'] as Map<String, dynamic>?;
    final reg = d?['driver_registration'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        title: Text(d?['name'] as String? ?? 'Vehicle Details',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : d == null
              ? const Center(child: Text('Vehicle not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (d['vehicle_photo'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: d['vehicle_photo'] as String,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _card([
                      _row('Name', d['name'] as String? ?? '—'),
                      _row('Type', d['vehicle_type'] as String? ?? '—'),
                      _row('Registration', d['vehicle_number'] as String? ?? '—'),
                      _row('Collections', '${d['total_collections'] ?? 0}'),
                      _row('Earnings', 'GH₵ ${d['total_earnings'] ?? '0'}'),
                      if (d['needs_admin_approval'] == true)
                        _row('Status', 'Pending admin approval'),
                    ]),
                    if (driver != null) ...[
                      const SizedBox(height: 12),
                      _card([
                        const Text('Assigned collector',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: _kTextDark)),
                        const SizedBox(height: 8),
                        _row('Name', driver['name'] as String? ?? '—'),
                        _row('Phone', driver['phone'] as String? ?? '—'),
                        _row(
                          'Account',
                          (driver['approved'] as bool? ?? false)
                              ? 'Approved — can log in'
                              : 'Pending approval',
                        ),
                      ]),
                    ],
                    if (reg != null) ...[
                      const SizedBox(height: 12),
                      _card([
                        _row('Ghana Card', reg['ghana_card_number'] as String? ?? '—'),
                        _row('License', reg['license_number'] as String? ?? '—'),
                        _row('Address', reg['address'] as String? ?? '—'),
                      ]),
                    ],
                    if (driver != null && (driver['approved'] as bool? ?? false) == false) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'The new collector (${driver['phone']}) can log in with their phone '
                          'once an admin approves the account.',
                          style: const TextStyle(color: _kTextGray, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: _kTextGray, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: _kTextDark, fontSize: 14))),
        ],
      ),
    );
  }
}

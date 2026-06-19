import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/api_constants.dart';
import '../services/api_service.dart';

const Color _kPrimary = Color(0xFF2E7D32);
const Color _kTextGray = Color(0xFF757575);

class InvestorFleetTab extends StatefulWidget {
  const InvestorFleetTab({super.key});

  @override
  State<InvestorFleetTab> createState() => _InvestorFleetTabState();
}

class _InvestorFleetTabState extends State<InvestorFleetTab> {
  List<dynamic> _rides = [];
  List<dynamic> _collectors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rides = await ApiService.get(ApiConstants.investorRides);
      final cols = await ApiService.get(ApiConstants.investorCollectors);
      if (!mounted) return;
      setState(() {
        _rides = (rides['rides'] as List?) ?? [];
        _collectors = (cols['collectors'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerRide() async {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    var management = 'bola_aba';
    int? collectorId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Register Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ride name')),
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Vehicle type')),
              TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'Plate number')),
              SwitchListTile(
                title: const Text('Managed by Bɔla Aba'),
                subtitle: Text(
                  management == 'bola_aba'
                      ? 'Bɔla Aba assigns collectors & charges 10% service fee'
                      : 'You manage collections yourself',
                ),
                value: management == 'bola_aba',
                activeThumbColor: _kPrimary,
                onChanged: (v) => setSheet(() => management = v ? 'bola_aba' : 'self'),
              ),
              if (management == 'self' && _collectors.isNotEmpty)
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Assign collector'),
                  items: _collectors
                      .where((c) => c['is_approved'] == true)
                      .map((c) => DropdownMenuItem(
                            value: c['id'] as int,
                            child: Text(c['full_name'] as String? ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) => collectorId = v,
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ApiService.post(ApiConstants.investorRides, {
                        'name': nameCtrl.text.trim(),
                        'vehicle_type': typeCtrl.text.trim(),
                        'vehicle_number': numberCtrl.text.trim(),
                        'management_mode': management,
                        if (collectorId != null) 'assigned_collector_id': collectorId,
                      });
                      _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                  child: const Text('Register Ride'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCollector() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final typeCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Collector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Vehicle type')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiService.post(ApiConstants.investorCollectors, {
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'vehicle_type': typeCtrl.text.trim(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Collector submitted for admin approval')),
                      );
                    }
                    _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                child: const Text('Submit for Approval'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRideDetail(Map<String, dynamic> ride) async {
    final id = ride['id'] as int;
    try {
      final data = await ApiService.get(ApiConstants.investorRide(id));
      if (!mounted) return;
      final detail = data['ride'] as Map<String, dynamic>? ?? ride;
      final collections = (data['collections'] as List?) ?? [];
      final lat = (detail['current_lat'] as num?)?.toDouble();
      final lng = (detail['current_lng'] as num?)?.toDouble();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              Text(detail['vehicle_type'] as String? ?? 'Ride',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              if ((detail['assignment_label'] as String? ?? '').isNotEmpty)
                Chip(
                  label: Text(detail['assignment_label'] as String),
                  backgroundColor: _kPrimary.withValues(alpha: 0.1),
                ),
              Text('Management: ${detail['management_label'] ?? ''}'),
              if (detail['assigned_collector'] != null) ...[
                const SizedBox(height: 8),
                Text('Collector: ${detail['assigned_collector']['full_name']}'),
              ],
              if (lat != null && lng != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lng),
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('ride'),
                        position: LatLng(lat, lng),
                      ),
                    },
                    zoomControlsEnabled: false,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Collections (${collections.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              ...collections.map((c) => ListTile(
                    dense: true,
                    title: Text(c['pickup_address'] as String? ?? ''),
                    subtitle: Text('GHS ${c['price']}'),
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Rides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton(onPressed: _addCollector, child: const Text('+ Collector')),
              ],
            ),
            if (_rides.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No rides registered yet.', style: TextStyle(color: _kTextGray)),
              )
            else
              ..._rides.map((r) {
                final ride = r as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(ride['vehicle_type'] as String? ?? 'Ride'),
                    subtitle: Text(
                      '${ride['management_label'] ?? ''} · ${ride['vehicle_number'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openRideDetail(ride),
                  ),
                );
              }),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: _registerRide,
            backgroundColor: _kPrimary,
            icon: const Icon(Icons.add),
            label: const Text('Register Ride'),
          ),
        ),
      ],
    );
  }
}

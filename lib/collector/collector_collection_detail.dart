import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/phone_utils.dart';

const Color _kPrimary = Color(0xFF2E7D32);
const Color _kBg = Color(0xFFF0F7F0);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

class CollectorCollectionDetailPage extends StatefulWidget {
  final int collectionId;
  const CollectorCollectionDetailPage({super.key, required this.collectionId});

  @override
  State<CollectorCollectionDetailPage> createState() =>
      _CollectorCollectionDetailPageState();
}

class _CollectorCollectionDetailPageState
    extends State<CollectorCollectionDetailPage> {
  Map<String, dynamic>? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context
          .read<AppProvider>()
          .fetchCollectorCollectionDetail(widget.collectionId);
      if (mounted) setState(() { _item = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final lat = item?['pickupLat'] as double?;
    final lng = item?['pickupLng'] as double?;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        title: Text('Collection #${widget.collectionId}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : item == null
              ? const Center(child: Text('Collection not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (lat != null && lng != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 180,
                          child: gm.GoogleMap(
                            initialCameraPosition:
                                gm.CameraPosition(target: gm.LatLng(lat, lng), zoom: 15),
                            markers: {
                              gm.Marker(
                                markerId: const gm.MarkerId('pickup'),
                                position: gm.LatLng(lat, lng),
                              ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _card([
                      _row('Customer', item['customerName'] as String? ?? '—'),
                      _row('Phone', item['customerPhone'] as String? ?? '—',
                          onTap: () {
                            final phone = item['customerPhone'] as String?;
                            if (phone != null && phone.isNotEmpty) {
                              callPhone(phone);
                            }
                          }),
                      _row('Location', item['location'] as String? ?? '—'),
                      _row('Waste type', item['wasteType'] as String? ?? '—'),
                      _row('Distance', '${item['distanceKm']} km'),
                      _row('Date', item['date'] as String? ?? '—'),
                    ]),
                    const SizedBox(height: 12),
                    _card([
                      _row('Base price', 'GH₵ ${item['basePrice']}'),
                      _row('Distance fee', 'GH₵ ${item['distanceFee']}'),
                      _row('Total paid', 'GH₵ ${item['price']}',
                          bold: true, color: _kPrimary),
                      _row('Payment', _paymentLabel(item['paymentType'] as String?)),
                      if (item['rating'] != null)
                        _row('Customer rating', '${item['rating']} ★'),
                    ]),
                  ],
                ),
    );
  }

  String _paymentLabel(String? t) {
    switch (t) {
      case 'mobile_money': return 'Mobile Money';
      case 'cash': return 'Cash';
      case 'card': return 'Card';
      default: return t ?? '—';
    }
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? color, VoidCallback? onTap}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: _kTextGray, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  color: color ?? _kTextDark,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: bold ? 16 : 14,
                )),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: child);
    }
    return child;
  }
}

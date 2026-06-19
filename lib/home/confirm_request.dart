import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../utils/map_markers.dart';

const Color _kBg = Color(0xFFF0F7F0);
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);
const String _kCurrency = 'GH₵';

// ── ConfirmRequestPage ────────────────────────────────────────────────────────

class ConfirmRequestPage extends StatefulWidget {
  const ConfirmRequestPage({super.key});

  @override
  State<ConfirmRequestPage> createState() => _ConfirmRequestPageState();
}

class _ConfirmRequestPageState extends State<ConfirmRequestPage> {
  late final AppProvider _provider;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _provider.addListener(_onProviderChange);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChange);
    super.dispose();
  }

  void _onProviderChange() {
    if (!mounted) return;
    final status = _provider.requestStatus;
    if (status == 'assigned' || status == 'on_way' || status == 'arrived') {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  Future<void> _doStartRequest() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      await _provider.startRequest();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  String _title(String? status) {
    if (status == 'finding') return 'Finding Collector...';
    if (status == 'proposed') return 'Waiting for Collector...';
    if (status == 'assigned') return 'Opening Payment...';
    return 'Confirm Request';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final status = provider.requestStatus;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final s = context.read<AppProvider>().requestStatus;
        if (s != null && s != 'completed') {
          context.read<AppProvider>().cancelRequest();
        }
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: status == 'finding' || status == 'proposed'
            ? null
            : AppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: _kTextDark),
                  onPressed: () {
                    final s = context.read<AppProvider>().requestStatus;
                    if (s != null && s != 'completed') {
                      context.read<AppProvider>().cancelRequest();
                    }
                    Navigator.pop(context);
                  },
                ),
                title: Text(
                  _title(status),
                  style: const TextStyle(
                    color: _kTextDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
        body: _buildBody(provider, status),
      ),
    );
  }

  Widget _buildBody(AppProvider provider, String? status) {
    if (status == 'finding') return _FindingView(provider: provider);
    if (status == 'proposed') return _WaitingView(provider: provider);
    if (status == 'assigned') {
      return const Center(
        child: CircularProgressIndicator(color: _kPrimary),
      );
    }
    return _DetailsView(
      provider: provider,
      onFindCollector: _doStartRequest,
      requesting: _requesting,
    );
  }
}

// ── Finding view — map + spinner ──────────────────────────────────────────────

class _FindingView extends StatefulWidget {
  final AppProvider provider;
  const _FindingView({required this.provider});

  @override
  State<_FindingView> createState() => _FindingViewState();
}

class _FindingViewState extends State<_FindingView> {
  Timer? _noCollectorTimer;
  bool _timedOut = false;
  gm.BitmapDescriptor? _pinIcon;
  gm.BitmapDescriptor? _arrowIcon;

  @override
  void initState() {
    super.initState();
    _noCollectorTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && widget.provider.requestStatus == 'finding') {
        setState(() => _timedOut = true);
      }
    });
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    final pin   = await MapMarkers.buildDestinationPin();
    final arrow = await MapMarkers.buildNavArrow();
    if (!mounted) return;
    setState(() { _pinIcon = pin; _arrowIcon = arrow; });
  }

  @override
  void dispose() {
    _noCollectorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerPt = widget.provider.customerLocation;
    const nearbyCollectors = <Map<String, dynamic>>[];

    return Column(
      children: [
        // ── Map (top 55 %) ────────────────────────────────────────
        Expanded(
          flex: 55,
          child: Stack(
            children: [
              gm.GoogleMap(
                initialCameraPosition: gm.CameraPosition(
                  target: gm.LatLng(customerPt.latitude, customerPt.longitude),
                  zoom: 14,
                ),
                markers: {
                  gm.Marker(
                    markerId: const gm.MarkerId('customer'),
                    position: gm.LatLng(customerPt.latitude, customerPt.longitude),
                    icon: _pinIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
                    anchor: const Offset(0.5, 1.0),
                  ),
                  ...nearbyCollectors.map((c) {
                    final loc = c['location'] as LatLng;
                    return gm.Marker(
                      markerId: gm.MarkerId('col_${c['id']}'),
                      position: gm.LatLng(loc.latitude, loc.longitude),
                      icon: _arrowIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueBlue),
                      anchor: const Offset(0.5, 0.5),
                      flat: true,
                    );
                  }),
                },
                circles: {
                  gm.Circle(
                    circleId: const gm.CircleId('search_radius'),
                    center: gm.LatLng(customerPt.latitude, customerPt.longitude),
                    radius: 1200,
                    fillColor: _kPrimary.withValues(alpha: 0.07),
                    strokeColor: _kPrimary.withValues(alpha: 0.25),
                    strokeWidth: 2,
                  ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
              // Back button overlay
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GestureDetector(
                    onTap: () {
                      context.read<AppProvider>().cancelRequest();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: _kTextDark, size: 20),
                    ),
                  ),
                ),
              ),
              // Status chip overlay
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kPrimary),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Searching...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _kTextDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Bottom content (45 %) ─────────────────────────────────
        Expanded(
          flex: 45,
          child: Container(
            color: _kCard,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_timedOut) ...[
                  Column(
                    children: [
                      const Icon(Icons.search_off,
                          color: _kTextGray, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'No Collectors Available',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All collectors in your area are busy.\nPlease try again in a few minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _kTextGray),
                      ),
                    ],
                  ),
                ] else ...[
                  Column(
                    children: [
                      const CircularProgressIndicator(
                          color: _kPrimary, strokeWidth: 3),
                      const SizedBox(height: 20),
                      const Text(
                        'Searching for a collector\nnear you...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Matching you with the best available\ncollector in your area.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _kTextGray),
                      ),
                    ],
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<AppProvider>().cancelRequest();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kTextGray,
                      side: const BorderSide(color: Color(0xFFBDBDBD)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _timedOut ? 'Go Back' : 'Cancel Search',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// ── Waiting for collector to accept ───────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  final AppProvider provider;
  const _WaitingView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final collector = provider.proposedCollector;
    return Column(
      children: [
        Expanded(
          flex: 45,
          child: Stack(
            children: [
              gm.GoogleMap(
                initialCameraPosition: gm.CameraPosition(
                  target: gm.LatLng(
                    provider.customerLocation.latitude,
                    provider.customerLocation.longitude,
                  ),
                  zoom: 14,
                ),
                markers: {
                  gm.Marker(
                    markerId: const gm.MarkerId('pickup'),
                    position: gm.LatLng(
                      provider.customerLocation.latitude,
                      provider.customerLocation.longitude,
                    ),
                    icon: gm.BitmapDescriptor.defaultMarkerWithHue(
                      gm.BitmapDescriptor.hueGreen,
                    ),
                  ),
                },
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GestureDetector(
                    onTap: () {
                      context.read<AppProvider>().cancelRequest();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: _kTextDark, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 55,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Collector Matched',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Waiting for the collector to accept in their app. '
                  'You will be prompted to pay once they confirm.',
                  style: TextStyle(fontSize: 13, color: _kTextGray),
                ),
                if (collector != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    collector['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _kTextDark,
                    ),
                  ),
                  Text(
                    collector['vehicle'] as String,
                    style: const TextStyle(fontSize: 12, color: _kTextGray),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.read<AppProvider>().skipProposedCollector(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Find Another Collector',
                      style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
// ── Details view (initial state) ─────────────────────────────────────────────

class _DetailsView extends StatelessWidget {
  final AppProvider provider;
  final VoidCallback onFindCollector;
  final bool requesting;
  const _DetailsView({
    required this.provider,
    required this.onFindCollector,
    required this.requesting,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('WASTE TYPE'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kLightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline,
                          color: _kPrimary, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        provider.selectedWasteType,
                        style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 16),
                const _FieldLabel('PICKUP ADDRESS'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_pin,
                        color: _kPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.pickupAddress,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _kTextDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.social_distance_outlined,
                        color: _kTextGray.withValues(alpha: 0.7),
                        size: 16),
                    const SizedBox(width: 8),
                    Text(
                      provider.collectorDistanceKm > 0
                          ? 'Nearest collector ~${provider.collectorDistanceKm.toStringAsFixed(1)} km away'
                          : 'Matching with nearby collectors in Sekondi-Takoradi',
                      style: const TextStyle(
                          fontSize: 13, color: _kTextGray),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _Card(
            child: Column(
              children: [
                _FeeRow(
                  label: 'Base price (${provider.selectedWasteType})',
                  value: '$_kCurrency ${provider.selectedWastePrice}',
                ),
                const SizedBox(height: 10),
                _FeeRow(
                  label: 'Distance fee',
                  value: 'Set when collector accepts',
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Est. Total',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _kTextDark),
                    ),
                    Text(
                      '$_kCurrency ${provider.selectedWastePrice}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _kPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: _kTextGray.withValues(alpha: 0.8), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Final price is set when a collector accepts. '
                    'You can accept or skip to find a closer collector.',
                    style: TextStyle(fontSize: 12, color: _kTextGray),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: requesting ? null : onFindCollector,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: requesting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Find Collector Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),

          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Edit Request',
                style: TextStyle(color: _kTextGray, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _kTextGray,
          letterSpacing: 1.1,
        ),
      );
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  const _FeeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: _kTextGray)),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, color: _kTextDark)),
        ],
      );
}


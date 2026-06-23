import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import 'collector_tracking.dart';
import 'collector_personal_info.dart';
import 'collector_vehicle_details.dart';
import 'collector_kyc.dart';
import 'collector_payment_withdrawal.dart';
import 'collector_notifications_page.dart';
import 'collector_help_support.dart';
import 'vehicles_screen.dart';
import 'collector_collection_detail.dart';
import 'collector_credit_score.dart';

// ── Shared colours ────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kDark = Color(0xFF1B5E20);
const Color _kGreen = Color(0xFF00C853); // bright online-green
const Color _kCard = Colors.white;
const Color _kBg = Color(0xFFF0F7F0);
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

// ── Root scaffold with bottom nav ─────────────────────────────────────────────
class CollectorHomePage extends StatefulWidget {
  const CollectorHomePage({super.key});

  @override
  State<CollectorHomePage> createState() => _CollectorHomePageState();
}

class _CollectorHomePageState extends State<CollectorHomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationService.promptIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          _CollectionsTab(),
          _EarningsTab(),
          _SchedulesTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _kPrimary,
          unselectedItemColor: _kTextGray,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Collections',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Schedules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with WidgetsBindingObserver {
  gm.GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  LatLng _collectorGps = const LatLng(4.9016, -1.7574); // ST default
  bool _gpsLoading = false;
  bool _locationDenied = false;
  Map<String, dynamic>? _lastIncomingRequest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      p.fetchCollectorProfile();
      p.fetchCollectorEarnings();
      p.fetchCollectorCollections();
      p.fetchAssignedSchedules();
      p.addListener(_onProviderChange);
    });
  }

  void _onProviderChange() {
    if (!mounted) return;
    final p = context.read<AppProvider>();
    final incoming = p.incomingRequest;
    if (incoming != null && incoming != _lastIncomingRequest) {
      _lastIncomingRequest = incoming;
      NotificationService.onIncomingRequestChanged(
        hasNew: true,
        customerName: incoming['customer_name'] as String?,
      );
    } else if (incoming == null) {
      if (_lastIncomingRequest != null) {
        NotificationService.onIncomingRequestChanged(hasNew: false);
      }
      _lastIncomingRequest = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    context.read<AppProvider>().removeListener(_onProviderChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _locationDenied) {
      _recheckPermission();
    }
  }

  Future<void> _recheckPermission() async {
    final perm = await Geolocator.checkPermission();
    if (!mounted) return;
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      setState(() => _locationDenied = false);
    }
  }

  Future<void> _handleToggle() async {
    final provider = context.read<AppProvider>();

    // Going offline
    if (provider.collectorOnline) {
      _positionSub?.cancel();
      _positionSub = null;
      try {
        await provider.toggleCollectorOnline();
      } catch (_) {}
      return;
    }

    // Going online → request GPS
    setState(() => _gpsLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _gpsLoading = false;
          _locationDenied = true;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _collectorGps = loc;
        _gpsLoading = false;
        _locationDenied = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _mapController?.animateCamera(gm.CameraUpdate.newCameraPosition(gm.CameraPosition(target: gm.LatLng(loc.latitude, loc.longitude), zoom: 16))),
      );
      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((p) {
        if (!mounted) return;
        final newLoc = LatLng(p.latitude, p.longitude);
        setState(() => _collectorGps = newLoc);
        if (provider.collectorOnline) {
          provider.pushCollectorLocation(p.latitude, p.longitude);
        }
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _mapController?.animateCamera(gm.CameraUpdate.newCameraPosition(gm.CameraPosition(target: gm.LatLng(newLoc.latitude, newLoc.longitude), zoom: 16))),
        );
      });
      await provider.toggleCollectorOnline(
        lat: pos.latitude,
        lng: pos.longitude,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _gpsLoading = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('approval') || msg.contains('approved')
                ? 'Your account is pending admin approval. You cannot go online yet.'
                : msg,
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final incoming = provider.incomingRequest;
    final confirmed = provider.confirmedActiveSchedule;

    return Stack(
      children: [
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeTopBar(provider: provider),
              const SizedBox(height: 4),
              _OnlineToggle(
                online: provider.collectorOnline,
                loading: _gpsLoading,
                onToggle: _handleToggle,
              ),
              const SizedBox(height: 14),
              _StatsRow(provider: provider),
              const SizedBox(height: 14),

              // Confirmed active schedule banner
              if (confirmed != null) ...[
                _ConfirmedScheduleBanner(
                  schedule: confirmed,
                  onNavigate: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CollectorTrackingPage(
                              request: {
                                'id': confirmed['id'],
                                'customerName': confirmed['customerName'],
                                'phone': confirmed['phone'] ?? '',
                                'location': confirmed['location'],
                                'wasteType': confirmed['wasteType'],
                                'price': confirmed['price'],
                                'distance': '—',
                                'timeAgo': 'Scheduled',
                              },
                            ),
                      ),
                    );
                  },
                  onDismiss: () => provider.clearConfirmedSchedule(),
                ),
                const SizedBox(height: 10),
              ] else
                _StatusCard(online: provider.collectorOnline),

              const SizedBox(height: 14),
              Expanded(
                child:
                    _locationDenied
                        ? const _LocationDeniedCard()
                        : _CollectorMap(
                          gps: _collectorGps,
                          onMapCreated: (ctrl) => setState(() => _mapController = ctrl),
                          online: provider.collectorOnline,
                        ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Incoming on-demand request overlay
        if (incoming != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _IncomingRequestSheet(request: incoming),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Home top bar ───────────────────────────────────────────────────────────────
class _HomeTopBar extends StatelessWidget {
  final AppProvider provider;
  const _HomeTopBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final profile = provider.collectorProfile;
    final name = (profile?['full_name'] as String?) ?? provider.displayName;
    final vehicle = (profile?['vehicle_type'] as String?) ?? '';
    final ratingNum = (profile?['rating'] as num?)?.toDouble() ?? 0.0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _kTextDark,
                  ),
                ),
                Text(
                  vehicle,
                  style: const TextStyle(color: _kTextGray, fontSize: 12),
                ),
              ],
            ),
          ),
          // Score badge — tappable stars
          GestureDetector(
            onTap: () => _showRatingSheet(context, ratingNum),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: ratingNum >= 4 ? _kLightGreen : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ratingNum >= 4 ? _kPrimary : Colors.amber,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: ratingNum >= 4 ? _kPrimary : Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ratingNum.toStringAsFixed(1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          ratingNum >= 4 ? _kPrimary : const Color(0xFF6D4C00),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingSheet(BuildContext context, double rating) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RatingSheet(rating: rating),
    );
  }
}

class _RatingSheet extends StatelessWidget {
  final double rating;
  const _RatingSheet({required this.rating});

  @override
  Widget build(BuildContext context) {
    final String label;
    if (rating >= 4.5) {
      label = 'Excellent — Keep it up!';
    } else if (rating >= 4.0) {
      label = 'Great — Customers love you!';
    } else if (rating >= 3.0) {
      label = 'Good — Room to improve';
    } else {
      label = 'Needs work — Focus on service';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Score',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _kPrimary,
            ),
          ),
          const Text(
            'out of 5.0',
            style: TextStyle(color: _kTextGray, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              if (i < rating.floor()) {
                return const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 32,
                );
              } else if (i < rating) {
                return const Icon(
                  Icons.star_half_rounded,
                  color: Colors.amber,
                  size: 32,
                );
              } else {
                return Icon(
                  Icons.star_outline_rounded,
                  color: Colors.grey.shade300,
                  size: 32,
                );
              }
            }),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: _kTextGray, fontSize: 14)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kLightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Tip: Arrive on time, be polite, and handle waste carefully to improve your score.',
              style: TextStyle(color: _kPrimary, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Online toggle ──────────────────────────────────────────────────────────────
class _OnlineToggle extends StatelessWidget {
  final bool online;
  final bool loading;
  final VoidCallback onToggle;
  const _OnlineToggle({
    required this.online,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: loading ? null : onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: online ? _kPrimary : const Color(0xFF37474F),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (online ? _kPrimary : const Color(0xFF37474F))
                    .withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Status dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? _kGreen : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  boxShadow:
                      online
                          ? [
                            const BoxShadow(
                              color: _kGreen,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                          : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading
                          ? 'Getting location…'
                          : (online ? 'You are Online' : 'You are Offline'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loading
                          ? 'Please wait…'
                          : (online
                              ? 'Receiving pickup requests'
                              : 'Tap to go online'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              loading
                  ? const SizedBox(
                    width: 52,
                    height: 28,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                  : _ToggleSwitch(on: online),
            ],
          ),
        ),
      ),
    );
  }
}

// iOS-style animated toggle switch
class _ToggleSwitch extends StatelessWidget {
  final bool on;
  const _ToggleSwitch({required this.on});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 52,
      height: 28,
      decoration: BoxDecoration(
        color: on ? _kGreen : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final AppProvider provider;
  const _StatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final rating =
        (provider.collectorProfile?['rating'] as num?)?.toDouble() ?? 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatCard(
            label: "Today's Earnings",
            value: 'GH₵ ${provider.todayEarnings.toStringAsFixed(2)}',
            icon: Icons.trending_up,
            color: _kPrimary,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Collections',
            value: '${provider.totalCollections}',
            icon: Icons.check_circle_outline,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Score',
            value: '${rating.toStringAsFixed(1)}★',
            icon: Icons.star_outline,
            color: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: _kTextGray, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status card ────────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final bool online;
  const _StatusCard({required this.online});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Icon(
              online ? Icons.signal_cellular_alt : Icons.wifi_off,
              color: online ? _kGreen : _kTextGray,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                online
                    ? 'Waiting for incoming pickup requests…'
                    : 'Toggle online to start receiving requests',
                style: TextStyle(
                  color: online ? _kTextDark : _kTextGray,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirmed schedule banner ──────────────────────────────────────────────────
class _ConfirmedScheduleBanner extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onNavigate;
  final VoidCallback onDismiss;
  const _ConfirmedScheduleBanner({
    required this.schedule,
    required this.onNavigate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today, color: _kGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Schedule Pickup',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    schedule['customerName'] as String,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Go',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map ────────────────────────────────────────────────────────────────────────
class _CollectorMap extends StatelessWidget {
  final LatLng gps;
  final void Function(gm.GoogleMapController) onMapCreated;
  final bool online;
  const _CollectorMap({
    required this.gps,
    required this.onMapCreated,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: gm.GoogleMap(
          initialCameraPosition: gm.CameraPosition(
            target: gm.LatLng(gps.latitude, gps.longitude),
            zoom: 15,
          ),
          onMapCreated: onMapCreated,
          markers: {
            gm.Marker(
              markerId: const gm.MarkerId('collector'),
              position: gm.LatLng(gps.latitude, gps.longitude),
              icon: gm.BitmapDescriptor.defaultMarkerWithHue(
                online
                    ? gm.BitmapDescriptor.hueGreen
                    : gm.BitmapDescriptor.hueRose,
              ),
            ),
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}

class _LocationDeniedCard extends StatelessWidget {
  const _LocationDeniedCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off,
                  color: Color(0xFFF57C00),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Access Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enable location services to go online and receive pickup requests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextGray, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Geolocator.openAppSettings(),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Enable Location →'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Incoming request overlay ───────────────────────────────────────────────────
class _IncomingRequestSheet extends StatefulWidget {
  final Map<String, dynamic> request;
  const _IncomingRequestSheet({required this.request});

  @override
  State<_IncomingRequestSheet> createState() => _IncomingRequestSheetState();
}

class _IncomingRequestSheetState extends State<_IncomingRequestSheet> {
  int _countdown = 30; // Give collector more time to review
  String _driveTime = '…';
  String _driveDistText = '…';

  @override
  void initState() {
    super.initState();
    _tick();
    _fetchDriveInfo();
  }

  /// Use OSRM to compute drive time from collector's current position to pickup.
  Future<void> _fetchDriveInfo() async {
    final r = widget.request;
    final collectorLat = r['collectorLat'] as double?;
    final collectorLng = r['collectorLng'] as double?;
    final pickupLat = r['pickupLat'] as double?;
    final pickupLng = r['pickupLng'] as double?;
    if (collectorLat == null || collectorLng == null ||
        pickupLat == null || pickupLng == null) return;
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$collectorLng,$collectorLat;$pickupLng,$pickupLat'
        '?overview=false',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final route = routes[0] as Map<String, dynamic>;
      final distM = (route['distance'] as num).toDouble();
      final durSec = (route['duration'] as num).toDouble();
      final mins = (durSec / 60).round();
      final distStr = distM >= 1000
          ? '${(distM / 1000).toStringAsFixed(1)} km'
          : '${distM.round()} m';
      if (!mounted) return;
      setState(() {
        _driveTime = mins > 0 ? '$mins min' : '< 1 min';
        _driveDistText = distStr;
      });
    } catch (_) {
      // Keep placeholders — OSRM may be unavailable
    }
  }

  void _tick() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        if (mounted) context.read<AppProvider>().declineRequest();
        return false;
      }
      return true;
    });
  }

  void _viewRoute() {
    final r = widget.request;
    final cLat = r['collectorLat'] as double?;
    final cLng = r['collectorLng'] as double?;
    final pLat = r['pickupLat'] as double?;
    final pLng = r['pickupLng'] as double?;
    if (cLat == null || pLat == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoutePreviewPage(
          collectorLat: cLat, collectorLng: cLng!,
          pickupLat: pLat, pickupLng: pLng!,
          address: r['location'] as String? ?? '',
          driveTime: _driveTime,
          driveDistance: _driveDistText,
          request: widget.request,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Pickup Request',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r['timeAgo'] as String? ?? '',
                        style: const TextStyle(color: _kTextGray, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Animated countdown ring
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _countdown / 30,
                        backgroundColor: Colors.grey.shade200,
                        color: _countdown > 15 ? _kPrimary : Colors.orange,
                        strokeWidth: 3,
                      ),
                      Text(
                        '$_countdown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _countdown > 15 ? _kPrimary : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),
            _Row(
              Icons.person_outline,
              'Customer',
              r['customerName'] as String? ?? '',
            ),
            _Row(Icons.phone_outlined, 'Phone', r['phone'] as String? ?? ''),
            _Row(
              Icons.location_on_outlined,
              'Location',
              r['location'] as String? ?? '',
            ),
            _Row(
              Icons.social_distance_outlined,
              'Distance',
              _driveDistText,
            ),
            _Row(
              Icons.access_time_outlined,
              'Drive Time',
              _driveTime,
            ),
            _Row(
              Icons.delete_outline,
              'Waste',
              r['wasteType'] as String? ?? '',
            ),
            _Row(Icons.payments_outlined, 'Earnings', 'GH₵ ${r['price']}'),
            const SizedBox(height: 18),
            // View Route button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _viewRoute,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kPrimary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.map_outlined, color: _kPrimary, size: 18),
                label: const Text(
                  'View Route on Map',
                  style: TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        () => context.read<AppProvider>().declineRequest(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final req = Map<String, dynamic>.from(widget.request);
                      context.read<AppProvider>().acceptRequest();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CollectorTrackingPage(request: req),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Route Preview Page ─────────────────────────────────────────────────────────
// Full-screen map shown when collector taps "View Route on Map".
// Shows the driving route from collector → pickup and lets them accept.
class _RoutePreviewPage extends StatefulWidget {
  final double collectorLat, collectorLng, pickupLat, pickupLng;
  final String address, driveTime, driveDistance;
  final Map<String, dynamic> request;

  const _RoutePreviewPage({
    required this.collectorLat,
    required this.collectorLng,
    required this.pickupLat,
    required this.pickupLng,
    required this.address,
    required this.driveTime,
    required this.driveDistance,
    required this.request,
  });

  @override
  State<_RoutePreviewPage> createState() => _RoutePreviewPageState();
}

class _RoutePreviewPageState extends State<_RoutePreviewPage> {
  gm.GoogleMapController? _mapCtrl;
  Set<gm.Polyline> _polylines = {};
  Set<gm.Marker> _markers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${widget.collectorLng},${widget.collectorLat};'
        '${widget.pickupLng},${widget.pickupLat}'
        '?overview=full&geometries=polyline',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0] as Map<String, dynamic>;
          final pts = _decodePolyline(route['geometry'] as String);
          setState(() {
            _polylines = {
              gm.Polyline(
                polylineId: const gm.PolylineId('route'),
                color: _kPrimary,
                width: 5,
                points: pts
                    .map((p) => gm.LatLng(p.latitude, p.longitude))
                    .toList(),
              ),
            };
          });
        }
      }
    } catch (_) {}

    // Always set markers even if route fetch fails
    if (!mounted) return;
    setState(() {
      _markers = {
        gm.Marker(
          markerId: const gm.MarkerId('collector'),
          position: gm.LatLng(widget.collectorLat, widget.collectorLng),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(
              gm.BitmapDescriptor.hueBlue),
          infoWindow: const gm.InfoWindow(title: 'You (Collector)'),
        ),
        gm.Marker(
          markerId: const gm.MarkerId('pickup'),
          position: gm.LatLng(widget.pickupLat, widget.pickupLng),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(
              gm.BitmapDescriptor.hueGreen),
          infoWindow: gm.InfoWindow(title: 'Pickup: ${widget.address}'),
        ),
      };
      _loading = false;
    });

    // Fit camera to both markers
    _mapCtrl?.animateCamera(
      gm.CameraUpdate.newLatLngBounds(
        gm.LatLngBounds(
          southwest: gm.LatLng(
            widget.collectorLat < widget.pickupLat
                ? widget.collectorLat
                : widget.pickupLat,
            widget.collectorLng < widget.pickupLng
                ? widget.collectorLng
                : widget.pickupLng,
          ),
          northeast: gm.LatLng(
            widget.collectorLat > widget.pickupLat
                ? widget.collectorLat
                : widget.pickupLat,
            widget.collectorLng > widget.pickupLng
                ? widget.collectorLng
                : widget.pickupLng,
          ),
        ),
        80,
      ),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final pts = <LatLng>[];
    int i = 0, lat = 0, lng = 0;
    while (i < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final midLat = (widget.collectorLat + widget.pickupLat) / 2;
    final midLng = (widget.collectorLng + widget.pickupLng) / 2;

    return Scaffold(
      body: Stack(
        children: [
          gm.GoogleMap(
            initialCameraPosition: gm.CameraPosition(
              target: gm.LatLng(midLat, midLng),
              zoom: 13.0,
            ),
            onMapCreated: (c) {
              _mapCtrl = c;
              if (!_loading) _fetchRoute();
            },
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: _kTextDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          // Info + Accept bottom panel
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InfoChip(
                            icon: Icons.access_time,
                            label: widget.driveTime),
                        _InfoChip(
                            icon: Icons.social_distance_outlined,
                            label: widget.driveDistance),
                        _InfoChip(
                            icon: Icons.payments_outlined,
                            label: 'GH₵ ${widget.request['price']}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.address,
                      style: const TextStyle(fontSize: 13, color: _kTextGray),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final req =
                              Map<String, dynamic>.from(widget.request);
                          context.read<AppProvider>().acceptRequest();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CollectorTrackingPage(request: req),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Accept Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _kPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _kTextDark,
            ),
          ),
        ],
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _kTextGray),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: const TextStyle(color: _kTextGray, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _kTextDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECTIONS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _CollectionsTab extends StatefulWidget {
  const _CollectionsTab();

  @override
  State<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<_CollectionsTab> {
  bool _loading = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<AppProvider>().fetchCollectorCollections(period: _filter);
    if (mounted) setState(() => _loading = false);
  }

  void _setFilter(String f) {
    setState(() => _filter = f);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final collections = provider.collectorCollections;
    final totalEarned = collections.fold<int>(
      0,
      (sum, c) => sum + ((c['price'] as num?)?.toInt() ?? 0),
    );

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Collections',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _kTextDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon:
                      _loading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kPrimary,
                            ),
                          )
                          : const Icon(Icons.refresh, color: _kPrimary),
                ),
              ],
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _filter == 'all', onTap: () => _setFilter('all')),
                _FilterChip(label: 'Today', selected: _filter == 'today', onTap: () => _setFilter('today')),
                _FilterChip(label: 'Yesterday', selected: _filter == 'yesterday', onTap: () => _setFilter('yesterday')),
                _FilterChip(label: 'This Week', selected: _filter == 'week', onTap: () => _setFilter('week')),
                _FilterChip(label: 'Completed', selected: _filter == 'completed', onTap: () => _setFilter('completed')),
              ],
            ),
          ),

          // Summary strip
          if (collections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  _SummaryPill(
                    icon: Icons.check_circle_outline,
                    label: '${collections.length} pickups',
                    color: _kPrimary,
                  ),
                  const SizedBox(width: 10),
                  _SummaryPill(
                    icon: Icons.payments_outlined,
                    label: 'GH₵ $totalEarned earned',
                    color: const Color(0xFF1565C0),
                  ),
                ],
              ),
            ),

          Expanded(
            child:
                collections.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No collections yet',
                            style: TextStyle(color: _kTextGray, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Go online to start accepting requests',
                            style: TextStyle(color: _kTextGray, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      color: _kPrimary,
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: collections.length,
                        itemBuilder:
                            (_, i) => _CollectionCard(item: collections[i]),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _kLightGreen,
        checkmarkColor: _kPrimary,
        labelStyle: TextStyle(
          color: selected ? _kPrimary : _kTextGray,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CollectionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final id = item['id'] as int? ?? 0;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CollectorCollectionDetailPage(collectionId: id),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: _kPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['customerName'] as String? ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['wasteType']} · ${item['location']}',
                  style: const TextStyle(color: _kTextGray, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item['date'] as String? ?? '',
                  style: const TextStyle(color: _kTextGray, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'GH₵ ${item['price']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kLightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: _kPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════════════════════
class _EarningsTab extends StatelessWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final totalEarned = p.totalEarnings;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Earnings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 20),

            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
                  const Text(
                    'Account Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'GH₵ ${p.accountBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showWithdrawDialog(context, p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Withdraw Funds',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Commission owed — always show, collapse when zero
            if (p.unpaidCommission > 0) ...[
              _CommissionCard(amount: p.unpaidCommission),
              const SizedBox(height: 14),
            ],

            // Credit score + debt summary
            Row(
              children: [
                _EarningsStatCard(
                  label: 'Credit Score',
                  value: '${p.creditScore}/100',
                  icon: Icons.stars,
                  color: const Color(0xFFEF6C00),
                ),
                const SizedBox(width: 10),
                _EarningsStatCard(
                  label: 'Debt Owed',
                  value: 'GH₵ ${p.unpaidCommission.toStringAsFixed(2)}',
                  icon: Icons.warning_amber_outlined,
                  color: p.unpaidCommission > 0 ? Colors.red.shade700 : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _EarningsStatCard(
                  label: 'Today',
                  value: 'GH₵ ${p.todayEarnings.toStringAsFixed(2)}',
                  icon: Icons.today,
                  color: _kPrimary,
                ),
                const SizedBox(width: 10),
                _EarningsStatCard(
                  label: 'This Week',
                  value: 'GH₵ ${p.weeklyEarnings.toStringAsFixed(2)}',
                  icon: Icons.date_range,
                  color: const Color(0xFF1565C0),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _EarningsStatCard(
                  label: 'All Time',
                  value: 'GH₵ ${totalEarned.toStringAsFixed(2)}',
                  icon: Icons.bar_chart,
                  color: const Color(0xFF6A1B9A),
                ),
                const SizedBox(width: 10),
                _EarningsStatCard(
                  label: 'Collections',
                  value: '${p.totalCollections}',
                  icon: Icons.check_circle_outline,
                  color: Colors.teal.shade600,
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 10),
            if (p.recentTransactions.isEmpty)
              const Text('No transactions yet', style: TextStyle(color: _kTextGray))
            else
              ...p.recentTransactions.take(8).map((t) => _ApiTransactionRow(item: t)),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, AppProvider p) async {
    await p.fetchCollectorPaymentMethods();
    if (!context.mounted) return;
    final amountCtrl = TextEditingController();
    int? selectedMethodId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final methods = p.collectorPaymentMethods;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Withdraw Funds',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Balance: GH₵ ${p.accountBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: _kTextGray)),
                  if (p.unpaidCommission > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Outstanding commission: GH₵ ${p.unpaidCommission.toStringAsFixed(2)} — deducted automatically.',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (GH₵)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [20, 50, 100, 200].map((v) {
                      return ActionChip(
                        label: Text('GH₵ $v'),
                        onPressed: () => amountCtrl.text = v.toString(),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Withdraw to', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (methods.isEmpty)
                    const Text('Add MoMo or bank in Payment & Withdrawal first.',
                        style: TextStyle(color: _kTextGray, fontSize: 12))
                  else
                    ...methods.map((m) {
                      final id = m['id'] as int;
                      final type = m['payment_type'] as String? ?? '';
                      final label = type == 'bank'
                          ? 'Bank · ${m['provider']} ${m['number']}'
                          : 'MoMo · ${m['provider']} ${m['number']}';
                      return RadioListTile<int>(
                        value: id,
                        groupValue: selectedMethodId,
                        onChanged: (v) => setSheet(() {
                          selectedMethodId = v;
                        }),
                        title: Text(label, style: const TextStyle(fontSize: 13)),
                      );
                    }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amt = double.tryParse(amountCtrl.text.trim());
                        if (amt == null || amt <= 0) return;
                        if (selectedMethodId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Select MoMo or bank wallet')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          final msg = await p.requestWithdrawal(
                            amt,
                            paymentMethodId: selectedMethodId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: _kPrimary),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Submit Withdrawal',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ApiTransactionRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ApiTransactionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as String? ?? '';
    final isDebit = type == 'commission';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isDebit ? Icons.remove_circle_outline : Icons.add_circle_outline,
            color: isDebit ? Colors.red : _kPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['description'] as String? ?? type,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(item['date'] as String? ?? '',
                    style: const TextStyle(color: _kTextGray, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${isDebit ? '-' : '+'}GH₵ ${(item['amount'] as num?)?.toStringAsFixed(2) ?? '0'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDebit ? Colors.red : _kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _EarningsStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                  Text(
                    label,
                    style: const TextStyle(color: _kTextGray, fontSize: 11),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TransactionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_downward, size: 16, color: _kPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['customerName'] as String? ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _kTextDark,
                  ),
                ),
                Text(
                  item['date'] as String? ?? '',
                  style: const TextStyle(color: _kTextGray, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '+GH₵ ${item['price']}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Commission card
class _CommissionCard extends StatelessWidget {
  final double amount;
  const _CommissionCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF57C00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commission Owed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF4E2C00),
                      ),
                    ),
                    Text(
                      '3.5% from cash collections not yet settled',
                      style: TextStyle(color: Color(0xFF7B4C00), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'GH₵ ${amount.toStringAsFixed(2)} — deducted automatically when you withdraw.',
            style: const TextStyle(color: Color(0xFF7B4C00), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULES TAB — with live countdown + popup alert
// ═══════════════════════════════════════════════════════════════════════════════
class _SchedulesTab extends StatefulWidget {
  const _SchedulesTab();

  @override
  State<_SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<_SchedulesTab> {
  Timer? _ticker;
  final Set<int> _alertedIds = {};
  final Map<int, DateTime> _snoozedUntil = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppProvider>().fetchAssignedSchedules();
      if (mounted) _startTicker();
    });
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        _checkDueSchedules();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _checkDueSchedules() {
    final schedules = context.read<AppProvider>().assignedSchedules;
    for (final s in schedules) {
      final id = s['id'] as int? ?? 0;
      final remaining = _remaining(s);
      if (remaining == null) continue;
      // Due when ≤ 0 seconds remain
      if (remaining.inSeconds <= 0 && !_alertedIds.contains(id)) {
        // Check snooze
        final snooze = _snoozedUntil[id];
        if (snooze != null && DateTime.now().isBefore(snooze)) continue;
        _alertedIds.add(id);
        _triggerAlert(s);
      }
    }
  }

  Future<void> _triggerAlert(Map<String, dynamic> schedule) async {
    // System notification
    await NotificationService.show(
      'Scheduled Pickup Time!',
      'Pickup for ${schedule['customerName']} is now due. Open the app to confirm.',
      id: 200 + ((schedule['id'] as int?) ?? 0),
    );

    if (!mounted) return;

    // In-app dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _ScheduleAlertDialog(
            schedule: schedule,
            onConfirm: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AppProvider>().confirmSchedulePickup(
                  (schedule['id'] as int?) ?? 0,
                );
              } catch (_) {}
            },
            onSnooze: (minutes) {
              Navigator.pop(ctx);
              final id = (schedule['id'] as int?) ?? 0;
              _snoozedUntil[id] = DateTime.now().add(
                Duration(minutes: minutes),
              );
              _alertedIds.remove(id);
            },
          ),
    );
  }

  Duration? _remaining(Map<String, dynamic> s) {
    final timeStr = s['pickupTime'] as String?;
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return dt.difference(DateTime.now());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedules = context.watch<AppProvider>().assignedSchedules;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Assigned Schedules',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _kTextDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      () =>
                          context.read<AppProvider>().fetchAssignedSchedules(),
                  icon: const Icon(Icons.refresh, color: _kPrimary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              '${schedules.length} upcoming',
              style: const TextStyle(color: _kTextGray, fontSize: 13),
            ),
          ),
          Expanded(
            child:
                schedules.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No schedules assigned',
                            style: TextStyle(color: _kTextGray, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Schedules assigned by admin will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kTextGray, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: schedules.length,
                      itemBuilder:
                          (_, i) => _ScheduleCard(
                            item: schedules[i],
                            remaining: _remaining(schedules[i]),
                          ),
                    ),
          ),
        ],
      ),
    );
  }
}

// ── Schedule card with countdown ───────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Duration? remaining;
  const _ScheduleCard({required this.item, required this.remaining});

  Color _countdownColor() {
    if (remaining == null) return _kTextGray;
    if (remaining!.isNegative) return Colors.red;
    if (remaining!.inMinutes < 15) return Colors.red;
    if (remaining!.inMinutes < 60) return const Color(0xFFF57C00);
    return _kPrimary;
  }

  String _countdownText() {
    if (remaining == null) return '—';
    if (remaining!.isNegative) return 'NOW!';
    final d = remaining!;
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours.remainder(24)}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = _countdownColor();
    final isUrgent =
        remaining != null &&
        !remaining!.isNegative &&
        remaining!.inMinutes < 15;
    final isPast = remaining != null && remaining!.isNegative;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isPast
                ? const Color(0xFFFFF3E0)
                : isUrgent
                ? const Color(0xFFFFF8F8)
                : _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isPast
                  ? const Color(0xFFFFCC80)
                  : isUrgent
                  ? const Color(0xFFFFCDD2)
                  : const Color(0xFFE8F5E9),
          width: isPast || isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Date box
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (item['dayName'] as String? ?? '').length >= 3
                          ? (item['dayName'] as String).substring(0, 3)
                          : (item['dayName'] as String? ?? ''),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.calendar_today, color: color, size: 18),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['customerName'] as String? ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['wasteType']} · ${item['location']}',
                      style: const TextStyle(color: _kTextGray, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item['dayName']}, ${item['date']} at ${item['time']}',
                      style: const TextStyle(color: _kTextGray, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                'GH₵ ${item['price']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _kPrimary,
                ),
              ),
            ],
          ),

          // Countdown row
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isPast
                      ? Icons.notification_important_outlined
                      : Icons.timer_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  isPast
                      ? 'Pickup time has arrived!'
                      : isUrgent
                      ? 'Due soon — '
                      : 'Time remaining: ',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _countdownText(),
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isPast) ...[
                  const Spacer(),
                  const Text(
                    'Waiting for confirm',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if ((item['scheduleStatus'] as String?) == 'active' ||
              (item['collectorConfirmed'] as bool? ?? false) && isPast) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final lat = item['pickupLat'] as double?;
                  final lng = item['pickupLng'] as double?;
                  if (lat != null && lng != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ScheduleMapPreview(
                          lat: lat,
                          lng: lng,
                          label: item['location'] as String? ?? 'Pickup',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('View pickup on map'),
                style: OutlinedButton.styleFrom(foregroundColor: _kPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleMapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final String label;
  const _ScheduleMapPreview({required this.lat, required this.lng, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(label, style: const TextStyle(fontSize: 15)),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
      ),
      body: gm.GoogleMap(
        initialCameraPosition: gm.CameraPosition(target: gm.LatLng(lat, lng), zoom: 15),
        markers: {
          gm.Marker(markerId: const gm.MarkerId('pickup'), position: gm.LatLng(lat, lng)),
        },
      ),
    );
  }
}
class _ScheduleAlertDialog extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Future<void> Function() onConfirm;
  final void Function(int minutes) onSnooze;
  const _ScheduleAlertDialog({
    required this.schedule,
    required this.onConfirm,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert icon — pulsing orange ring
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.alarm,
                color: Color(0xFFF57C00),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pickup Time!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scheduled pickup for ${schedule['customerName']} is now ready.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kTextGray,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kLightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _AlertRow(
                    Icons.delete_outline,
                    'Waste',
                    schedule['wasteType'] as String? ?? '',
                  ),
                  const SizedBox(height: 6),
                  _AlertRow(
                    Icons.location_on_outlined,
                    'Location',
                    schedule['location'] as String? ?? '',
                  ),
                  const SizedBox(height: 6),
                  _AlertRow(
                    Icons.payments_outlined,
                    'Earnings',
                    'GH₵ ${schedule['price']}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Confirming will mark this collection as active on your home screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6D4C00),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Confirm Pickup',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Snooze options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onSnooze(10),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Snooze 10m',
                      style: TextStyle(color: _kTextGray, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onSnooze(30),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Snooze 30m',
                      style: TextStyle(color: _kTextGray, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _AlertRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _kPrimary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: _kTextGray, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _kTextDark,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Log Out'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    final nav = Navigator.of(context);
    final provider = context.read<AppProvider>();
    await provider.logout();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final profile = p.collectorProfile;
    final name = (profile?['full_name'] as String?) ?? p.displayName;
    final vehicle = (profile?['vehicle_type'] as String?) ?? 'Vehicle';
    final phone =
        (profile?['phone'] as String?) ??
        (p.currentUser?['phone'] as String?) ??
        '';
    final email = (p.currentUser?['email'] as String?) ?? '';
    final rating = (profile?['rating'] as num?)?.toDouble() ?? 0.0;
    final approved = p.collectorApproved;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: const BoxDecoration(
                color: _kDark,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Approval badge
                  if (!approved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Pending approval',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Avatar
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        p.displayInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...List.generate(5, (i) {
                        if (i < rating.floor()) {
                          return const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 22,
                          );
                        } else if (i < rating) {
                          return const Icon(
                            Icons.star_half_rounded,
                            color: Colors.amber,
                            size: 22,
                          );
                        } else {
                          return Icon(
                            Icons.star_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 22,
                          );
                        }
                      }),
                      const SizedBox(width: 8),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Contact chips
                  if (phone.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            phone,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ProfileStat(
                    label: 'Collections',
                    value: '${p.totalCollections}',
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 10),
                  _ProfileStat(
                    label: 'Earnings',
                    value: 'GH₵ ${p.totalEarnings.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(width: 10),
                  _ProfileStat(
                    label: 'Score',
                    value: '${rating.toStringAsFixed(1)}★',
                    icon: Icons.star_outline,
                    valueColor: Colors.amber.shade700,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Menu items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: Icons.person_outline,
                    label: 'Personal Information',
                    sub: name,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CollectorPersonalInfoPage(),
                          ),
                        ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'Vehicle Details',
                    sub: vehicle,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CollectorVehicleDetailsPage(),
                          ),
                        ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.directions_car_outlined,
                    label: 'My Vehicles',
                    sub: 'Manage multiple vehicles',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CollectorVehiclesPage(),
                          ),
                        ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payment & Withdrawal',
                    sub: 'GH₵ ${p.accountBalance.toStringAsFixed(2)} balance',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => const CollectorPaymentWithdrawalPage(),
                          ),
                        ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.verified_user_outlined,
                    label: 'KYC Verification',
                    sub: 'Identity & documents',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CollectorKycPage()),
                    ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.stars_outlined,
                    label: 'Credit Score: ${p.creditScore}/100',
                    sub: p.creditScore >= 80 ? 'Excellent' : p.creditScore >= 50 ? 'Good' : 'Needs improvement',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CollectorCreditScorePage()),
                    ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.star_outline,
                    label: 'Reviews & Ratings',
                    sub: '${rating.toStringAsFixed(1)} / 5.0',
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _kPrimary,
                                ),
                              ),
                              const Text('Average customer rating',
                                  style: TextStyle(color: _kTextGray)),
                              const SizedBox(height: 8),
                              Text(
                                '${profile?['rating_count'] ?? 0} reviews from completed pickups',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _kTextGray, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CollectorNotificationsPage(),
                          ),
                        ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CollectorHelpSupportPage(),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _confirmLogout,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? valueColor;
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: _kPrimary),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: valueColor ?? _kTextDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: _kTextGray, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _kLightGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _kPrimary, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kTextDark,
          ),
        ),
        subtitle:
            sub != null && sub!.isNotEmpty
                ? Text(
                  sub!,
                  style: const TextStyle(color: _kTextGray, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                : null,
        trailing: const Icon(Icons.chevron_right, color: _kTextGray, size: 20),
        onTap: onTap,
      ),
    );
  }
}

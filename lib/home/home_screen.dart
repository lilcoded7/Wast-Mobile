import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/tracking_service.dart';
import '../utils/map_markers.dart';
import '../utils/parse_utils.dart';
import '../utils/phone_utils.dart';
import 'history.dart';
import 'notification.dart';
import 'profile_screen.dart';
import 'report_dumping.dart';
import 'request.dart';
import 'schedule_pickup.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const Color kBg = Color(0xFFF0F7F0);
const Color kPrimary = Color(0xFF2E7D32);
const Color kDark = Color(0xFF1B5E20);
const Color kCard = Colors.white;
const Color kLightGreen = Color(0xFFE8F5E9);
const Color kTextDark = Color(0xFF1A1A1A);
const Color kTextGray = Color(0xFF757575);
const Color _kBlue = Color(0xFF1A73E8);
const String kCurrency = 'GH₵';

// ── Default map centre: Sekondi-Takoradi, Ghana ───────────────────────────────
const _kDefaultCenter = LatLng(4.9016, -1.7574);

// ── Grid background painter ───────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = kPrimary.withValues(alpha: 0.07)
          ..strokeWidth = 0.8;
    const step = 30.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── HomeScreen ────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Sekondi-Takoradi service area: city centre + 25 km radius
const _kServiceCenter = LatLng(4.9016, -1.7574);
const _kServiceRadiusKm = 25.0;

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationService.promptIfNeeded(context);
    });
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning, 👋';
    if (h < 17) return 'Good afternoon, 👋';
    return 'Good evening, 👋';
  }

  // Returns true if [pos] is within the Sekondi-Takoradi service area.
  bool _inServiceArea(geo.Position pos) {
    final dist = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(pos.latitude, pos.longitude),
      _kServiceCenter,
    );
    return dist <= _kServiceRadiusKm;
  }

  // Checks location, then navigates to [page] — or shows "not available" dialog.
  Future<void> _goToPickup(Widget page) async {
    geo.Position? pos;
    try {
      pos = await geo.Geolocator.getLastKnownPosition();
      pos ??= await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {}

    if (!mounted) return;

    if (pos != null && !_inServiceArea(pos)) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(Icons.location_off, color: Color(0xFFD32F2F)),
                  SizedBox(width: 10),
                  Text('Not Available'),
                ],
              ),
              content: const Text(
                'WastePick currently serves Sekondi-Takoradi, Ghana only.\n\n'
                'Service is not available in your current location.',
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _currentIndex = 0);
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServiceHistoryPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    }
  }

  BottomNavigationBar _buildBottomNav(int index) => BottomNavigationBar(
    backgroundColor: Colors.white,
    selectedItemColor: kPrimary,
    unselectedItemColor: Colors.grey,
    currentIndex: index,
    onTap: _onNavTap,
    elevation: 8,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // ── Active request: show ONLY the live map — no action buttons ──
    if (provider.hasActiveRequest) {
      return Scaffold(
        backgroundColor: Colors.black,
        bottomNavigationBar: _buildBottomNav(0),
        body: _ActiveRequestMapView(
          key: ValueKey(provider.activeRequest?['id']),
        ),
      );
    }

    // ── Normal home ───────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: _buildBottomNav(_currentIndex),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: kBg,
              child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _timeGreeting(),
                            style: const TextStyle(fontSize: 13, color: kTextGray),
                          ),
                          Text(
                            provider.displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationPage(),
                              ),
                            ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: kTextDark,
                                size: 22,
                              ),
                            ),
                            if (provider.unreadNotifications > 0)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    '${provider.unreadNotifications}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _NoRequestCard(),
                        const SizedBox(height: 24),
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            _QuickActionCard(
                              icon: Icons.delete_outlined,
                              label: 'Request Pickup',
                              color: kPrimary,
                              onTap:
                                  () => _goToPickup(const RequestPickupPage()),
                            ),
                            _QuickActionCard(
                              icon: Icons.calendar_month_outlined,
                              label: 'Schedule',
                              color: const Color(0xFF1565C0),
                              onTap:
                                  () => _goToPickup(const SchedulePickupPage()),
                            ),
                            _QuickActionCard(
                              icon: Icons.campaign_outlined,
                              label: 'Report Dump',
                              color: const Color(0xFFD32F2F),
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ReportDumpingPage(),
                                    ),
                                  ),
                            ),
                            _QuickActionCard(
                              icon: Icons.history,
                              label: 'History',
                              color: kTextGray,
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const ServiceHistoryPage(),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Waste Types',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.wasteTypes.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 12),
                            itemBuilder:
                                (_, i) => _WasteTypeCard(
                                  wasteType: provider.wasteTypes[i],
                                  onTap:
                                      () => _goToPickup(
                                        const RequestPickupPage(),
                                      ),
                                ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVE REQUEST MAP VIEW
// Replaces the entire home body whenever ANY active request exists.
// Handles three states:
//   finding   → pulsing pickup pin, "Searching…" sheet
//   proposed  → collector pin + route + "Accept & Pay" sheet
//   tracking  → live route updates + status sheet
// ══════════════════════════════════════════════════════════════════════════════

class _ActiveRequestMapView extends StatefulWidget {
  const _ActiveRequestMapView({super.key});

  @override
  State<_ActiveRequestMapView> createState() => _ActiveRequestMapViewState();
}

class _ActiveRequestMapViewState extends State<_ActiveRequestMapView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Map ──────────────────────────────────────────────────────────────────
  gm.GoogleMapController? _mapController;
  Set<gm.Marker> _gmMarkers = {};
  Set<gm.Polyline> _gmPolylines = {};
  bool _mapReady = false;
  bool _cameraLocked = true; // follow collector when true

  // ── Custom marker icons ───────────────────────────────────────────────────
  gm.BitmapDescriptor? _dotIcon;
  gm.BitmapDescriptor? _arrowIcon;
  gm.BitmapDescriptor? _pinIcon;

  // ── Core positions ────────────────────────────────────────────────────────
  late LatLng _pickupPos;
  late LatLng _collectorPos;
  LatLng? _customerGpsPos;

  // ── Smooth collector marker animation ─────────────────────────────────────
  late AnimationController _markerAnimCtrl;
  late LatLng _markerFrom;
  late LatLng _markerTo;

  // ── Route (OSRM, road-following) ──────────────────────────────────────────
  double _routeDistM = 0;
  double _routeEtaSecs = 0;
  Timer? _routeThrottle;
  DateTime? _lastRouteFetch;

  // ── WebSocket ─────────────────────────────────────────────────────────────
  final _ws = TrackingService();
  StreamSubscription? _wsSub;

  // ── GPS stream ────────────────────────────────────────────────────────────
  StreamSubscription<geo.Position>? _gpsSub;

  // ── Local WS-reported status ──────────────────────────────────────────────
  String? _wsStatus;
  String? _lastKnownStatus; // tracks previous status for banner dedup

  // ── Status banner ─────────────────────────────────────────────────────────
  String? _bannerMsg;
  Color _bannerColor = kPrimary;
  IconData _bannerIcon = Icons.info_outline;
  bool _bannerVisible = false;
  Timer? _bannerTimer;

  // ── Payment state ─────────────────────────────────────────────────────────
  bool _paying = false;

  // ── Guard against double-navigation to /pickup-complete ───────────────────
  bool _navigatingToComplete = false;

  // ── Track whether customer has already confirmed payment ──────────────────
  // Once the customer pays for an 'assigned' request, flip this flag so we
  // show the tracking sheet instead of the payment sheet again.
  bool _paidAndConfirmed = false;

  // ── Provider ref ──────────────────────────────────────────────────────────
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<AppProvider>();
    _provider.addListener(_onProviderChange);

    final req = _provider.activeRequest;

    // ── Pickup pin: stored ST coordinates from request ──
    final pLat = parseDoubleOrNull(req?['pickup_lat']);
    final pLng = parseDoubleOrNull(req?['pickup_lng']);
    _pickupPos =
        (pLat != null && pLng != null) ? LatLng(pLat, pLng) : _kDefaultCenter;

    // ── Collector pin: most-recent known position ──
    final profile = req?['collector_profile'] as Map<String, dynamic>?;
    final cLat = parseDoubleOrNull(profile?['current_lat']);
    final cLng = parseDoubleOrNull(profile?['current_lng']);
    _collectorPos =
        (cLat != null && cLng != null)
            ? LatLng(cLat, cLng)
            : LatLng(_pickupPos.latitude + 0.012, _pickupPos.longitude - 0.018);
    _markerFrom = _collectorPos;
    _markerTo = _collectorPos;

    // Smooth marker animation — interpolates collector position over 900 ms
    _markerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
      if (!mounted) return;
      final t = _markerAnimCtrl.value;
      setState(() {
        _collectorPos = LatLng(
          _markerFrom.latitude +
              (_markerTo.latitude - _markerFrom.latitude) * t,
          _markerFrom.longitude +
              (_markerTo.longitude - _markerFrom.longitude) * t,
        );
      });
      if (_mapReady && _cameraLocked) _followBoth();
    });

    _lastKnownStatus = _provider.requestStatus;
    _loadMapIcons();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGps();
      _connectWs();
      final s = _provider.requestStatus;
      // Fetch route as soon as we know a collector position
      if (s == 'proposed' || s == 'assigned' || _provider.isTrackingActive) {
        _fetchRoute();
      }
      // If rejoining an already-paid request (on_way / arrived), mark as paid
      if (s == 'on_way' || s == 'arrived') {
        _paidAndConfirmed = true;
      }
    });
  }

  Future<void> _loadMapIcons() async {
    final dot   = await MapMarkers.buildLocationDot();
    final arrow = await MapMarkers.buildNavArrow();
    final pin   = await MapMarkers.buildDestinationPin();
    if (!mounted) return;
    setState(() {
      _dotIcon   = dot;
      _arrowIcon = arrow;
      _pinIcon   = pin;
      _updateMarkers();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.removeListener(_onProviderChange);
    _markerAnimCtrl.dispose();
    _bannerTimer?.cancel();
    _wsSub?.cancel();
    _ws.dispose();
    _gpsSub?.cancel();
    _routeThrottle?.cancel();
    super.dispose();
  }

  // ── Provider listener ─────────────────────────────────────────────────────
  void _onProviderChange() {
    if (!mounted) return;
    final s = _provider.requestStatus;
    if (s == 'completed' && !_navigatingToComplete) {
      _navigatingToComplete = true;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/pickup-complete',
        (_) => false,
      );
      return;
    }
    // Trigger banner only on real status transitions
    if (s != null && s != _lastKnownStatus) {
      _lastKnownStatus = s;
      _triggerBanner(s);
      NotificationService.onRequestStatusChanged(
        s,
        collectorName: _provider.activeRequest?['collector_name'] as String?,
      );
    }
    // Sync collector position from provider animation when WS not yet active
    if (!_ws.isConnected) {
      final loc = _provider.collectorLocation;
      _animateCollectorTo(LatLng(loc.latitude, loc.longitude));
    }
    // When status moves to 'assigned' (collector accepted), fetch route so
    // the customer sees drive distance/time on the payment sheet.
    if (s == 'assigned' && !_ws.isConnected) {
      _connectWs();
      _fetchRoute();
    }
    // When collector starts driving, connect WS for live tracking
    if (s == 'on_way' && !_ws.isConnected) {
      _connectWs();
      _fetchRoute();
    }
  }

  // ── Smooth marker interpolation ────────────────────────────────────────────
  void _animateCollectorTo(LatLng target) {
    if (!mounted) return;
    _markerFrom = _collectorPos;
    _markerTo = target;
    _markerAnimCtrl.forward(from: 0);
  }

  // ── Status banner ──────────────────────────────────────────────────────────
  void _triggerBanner(String status) {
    final cfg = switch (status) {
      'proposed' => (
        'Collector matched — waiting for them to confirm…',
        kPrimary,
        Icons.person_search_outlined,
      ),
      'assigned' => (
        'Collector confirmed! Please confirm & pay to start pickup',
        kPrimary,
        Icons.check_circle_outline,
      ),
      'on_way' => (
        'Collector is on the way!',
        const Color(0xFF1565C0),
        Icons.local_shipping_outlined,
      ),
      'arrived' => (
        'Your collector has arrived!',
        const Color(0xFF6A1B9A),
        Icons.location_on_outlined,
      ),
      'completed' => (
        'Pickup complete — thank you!',
        kPrimary,
        Icons.celebration_outlined,
      ),
      'cancelled' => (
        'Your pickup was cancelled',
        const Color(0xFFC62828),
        Icons.cancel_outlined,
      ),
      _ => ('', kPrimary, Icons.info_outline),
    };
    if (cfg.$1.isEmpty) return;
    _bannerTimer?.cancel();
    setState(() {
      _bannerMsg = cfg.$1;
      _bannerColor = cfg.$2;
      _bannerIcon = cfg.$3;
      _bannerVisible = true;
    });
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _bannerVisible = false);
    });
  }

  // ── Real-time GPS (customer "you are here") ───────────────────────────────
  Future<void> _initGps() async {
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      return;
    }

    // Get current position
    try {
      final p = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        setState(() => _customerGpsPos = LatLng(p.latitude, p.longitude));
      }
    } catch (_) {}

    // Background-aware stream settings
    final geo.LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.iOS
            ? geo.AppleSettings(
              accuracy: geo.LocationAccuracy.high,
              distanceFilter: 10,
              pauseLocationUpdatesAutomatically: false,
              showBackgroundLocationIndicator: true,
              activityType: geo.ActivityType.otherNavigation,
            )
            : const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
              distanceFilter: 10,
            );

    _gpsSub = geo.Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((p) {
      if (!mounted) return;
      setState(() => _customerGpsPos = LatLng(p.latitude, p.longitude));
    });
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────
  Future<void> _connectWs() async {
    final requestId = _provider.activeRequest?['id'] as int?;
    final token = await ApiService.getAccessToken();
    if (token == null || requestId == null) return;
    _ws.connect(requestId, token);
    _wsSub ??= _ws.stream.listen(_onWsMessage);
  }

  void _onWsMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String?;
    if (type == 'location_update') {
      final lat = parseDouble(data['latitude']);
      final lng = parseDouble(data['longitude']);
      _animateCollectorTo(LatLng(lat, lng));
      _updateMarkers();
      _throttledFetchRoute();
    } else if (type == 'status_update') {
      final s = data['status'] as String?;
      if (s != null && s != _wsStatus) {
        setState(() => _wsStatus = s);
        _triggerBanner(s);
        NotificationService.onRequestStatusChanged(
          s,
          collectorName: _provider.activeRequest?['collector_name'] as String?,
        );
      }
      if (s == 'arrived') {
        _moveCamera(_pickupPos, 17.5);
      }
      if (s == 'completed' && mounted && !_navigatingToComplete) {
        _navigatingToComplete = true;
        _provider.completeRequest();
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/pickup-complete',
          (_) => false,
        );
      }
    }
  }

  // ── Camera helpers ────────────────────────────────────────────────────────
  void _moveCamera(LatLng latLng, double zoom) {
    if (!_mapReady) return;
    _mapController?.animateCamera(
      gm.CameraUpdate.newCameraPosition(
        gm.CameraPosition(
          target: gm.LatLng(latLng.latitude, latLng.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  void _updateMarkers() {
    final s = _wsStatus ?? _provider.requestStatus;
    final markers = <gm.Marker>{};

    if (_customerGpsPos != null) {
      markers.add(gm.Marker(
        markerId: const gm.MarkerId('customer_gps'),
        position: gm.LatLng(_customerGpsPos!.latitude, _customerGpsPos!.longitude),
        icon: _dotIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
        infoWindow: const gm.InfoWindow(title: 'You'),
        anchor: const Offset(0.5, 0.5),
      ));
    }

    markers.add(gm.Marker(
      markerId: const gm.MarkerId('pickup'),
      position: gm.LatLng(_pickupPos.latitude, _pickupPos.longitude),
      icon: _pinIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
      infoWindow: const gm.InfoWindow(title: 'Pickup'),
      anchor: const Offset(0.5, 1.0),
    ));

    if (s == 'proposed' || s == 'assigned' || s == 'on_way' || s == 'arrived') {
      markers.add(gm.Marker(
        markerId: const gm.MarkerId('collector'),
        position: gm.LatLng(_collectorPos.latitude, _collectorPos.longitude),
        icon: _arrowIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueBlue),
        infoWindow: const gm.InfoWindow(title: 'Collector'),
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));
    }

    setState(() => _gmMarkers = markers);
  }

  void _followBoth() {
    final midLat = (_collectorPos.latitude + _pickupPos.latitude) / 2;
    final midLng = (_collectorPos.longitude + _pickupPos.longitude) / 2;
    final distKm = const Distance().as(
      LengthUnit.Kilometer,
      _collectorPos,
      _pickupPos,
    );
    // Zoom in progressively as collector gets closer to pickup
    final zoom =
        distKm > 4.0
            ? 12.5
            : distKm > 2.0
            ? 13.5
            : distKm > 0.8
            ? 14.5
            : distKm > 0.3
            ? 15.5
            : distKm > 0.1
            ? 16.5
            : 17.5;
    _moveCamera(LatLng(midLat, midLng), zoom);
  }

  void _fitBoth() {
    setState(() => _cameraLocked = false);
    _followBoth();
  }

  // ── Google Directions route ───────────────────────────────────────────────
  void _throttledFetchRoute() {
    final now = DateTime.now();
    if (_lastRouteFetch != null &&
        now.difference(_lastRouteFetch!).inSeconds < 5) {
      return;
    }
    _routeThrottle?.cancel();
    _routeThrottle = Timer(const Duration(seconds: 2), _fetchRoute);
  }

  Future<void> _fetchRoute() async {
    if (!mounted) return;
    _lastRouteFetch = DateTime.now();
    try {
      // OSRM open routing — road-following polylines, no API key needed
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_collectorPos.longitude},${_collectorPos.latitude};'
        '${_pickupPos.longitude},${_pickupPos.latitude}'
        '?overview=full&geometries=polyline',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (!mounted || res.statusCode != 200) {
        _setFallbackRoute();
        return;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        _setFallbackRoute();
        return;
      }
      final route   = routes[0] as Map<String, dynamic>;
      final dist    = (route['distance'] as num).toDouble();
      final dur     = (route['duration'] as num).toDouble();
      final encoded = route['geometry'] as String;
      final points  = _decodePolyline(encoded);
      if (!mounted) return;
      setState(() {
        _routeDistM = dist;
        _routeEtaSecs = dur;
        _gmPolylines = MapMarkers.routePolylines(
          points: points.map((p) => gm.LatLng(p.latitude, p.longitude)).toList(),
        );
      });
      if (_mapReady && _cameraLocked) _followBoth();
    } catch (_) {
      _setFallbackRoute();
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _setFallbackRoute() {
    if (!mounted) return;
    setState(() {
      _gmPolylines = MapMarkers.fallbackPolylines(
        points: [
          gm.LatLng(_collectorPos.latitude, _collectorPos.longitude),
          gm.LatLng(_pickupPos.latitude, _pickupPos.longitude),
        ],
      );
    });
  }

  // ── Formatters ────────────────────────────────────────────────────────────
  String get _etaText {
    if (_routeEtaSecs > 0) {
      final m = (_routeEtaSecs / 60).round();
      if (m >= 60) {
        final h = m ~/ 60;
        final rem = m % 60;
        return rem > 0 ? '$h hr $rem min' : '$h hr';
      }
      return m > 0 ? '$m min' : '< 1 min';
    }
    return '--';
  }

  String get _distText =>
      _routeDistM > 0
          ? (_routeDistM >= 1000
              ? '${(_routeDistM / 1000).toStringAsFixed(1)} km'
              : '${_routeDistM.round()} m')
          : '--';

  // ── Payment flow (shown when status == 'assigned') ────────────────────────
  void _onAcceptAndPay() {
    final price = _provider.proposedPrice;
    final defaultPhone = (_provider.currentUser?['phone'] as String?) ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _PaymentSheet(
            price: price,
            defaultPhone: defaultPhone,
            onPay: (phone) async {
              Navigator.pop(context);
              setState(() => _paying = true);
              try {
                await _provider.payAndAccept(phone);
                if (mounted) setState(() => _paidAndConfirmed = true);
                await _showPaymentSuccess();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _paying = false);
              }
            },
          ),
    );
  }

  Future<void> _showPaymentSuccess() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kLightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: kPrimary,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_android, size: 16, color: kTextGray),
                const SizedBox(width: 6),
                const Text(
                  'Mobile Money',
                  style: TextStyle(fontSize: 14, color: kTextGray),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$kCurrency ${_provider.proposedPrice}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Connecting to collector…',
              style: TextStyle(fontSize: 12, color: kTextGray),
            ),
          ],
        ),
      ),
    );
    // Auto-dismiss after 2 s then continue to live tracking
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _onSkipCollector() async {
    try {
      await _provider.skipProposedCollector();
    } catch (_) {}
  }

  void _onCancel() => _provider.cancelRequest();

  void _onConfirmComplete() {
    if (_navigatingToComplete) return;
    _navigatingToComplete = true;
    _provider.completeRequest();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/pickup-complete',
      (_) => false,
    );
  }

  // ── Markers ───────────────────────────────────────────────────────────────
  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final status = _wsStatus ?? _provider.requestStatus ?? 'finding';
    final isFinding = status == 'finding';
    // 'proposed' = system matched a collector but collector hasn't accepted yet
    final isProposed = status == 'proposed';
    // 'assigned' = collector accepted; customer should confirm + pay
    final isAssigned = status == 'assigned' && !_paidAndConfirmed;
    final isArrived = status == 'arrived';

    // Bottom sheet sizing
    final double sheetInit =
        isFinding
            ? 0.30
            : isProposed
            ? 0.28
            : isAssigned
            ? 0.55
            : 0.38;
    final double sheetMin = isFinding ? 0.25 : isProposed ? 0.22 : 0.28;
    final double sheetMax = isAssigned ? 0.78 : 0.68;

    return Stack(
      children: [
        gm.GoogleMap(
          initialCameraPosition: gm.CameraPosition(
            target: gm.LatLng(_pickupPos.latitude, _pickupPos.longitude),
            zoom: 14.0,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            setState(() => _mapReady = true);
            _updateMarkers();
            _followBoth();
            if (!isFinding) _fetchRoute();
          },
          markers: _gmMarkers,
          polylines: _gmPolylines,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onTap: (_) => setState(() => _cameraLocked = false),
        ),

        // ── ETA pill (collector → pickup) ──────────────────────────────
        if (_mapReady && _routeEtaSecs > 0 && !isFinding)
          Positioned(
            left: 16,
            bottom: MediaQuery.of(context).size.height * sheetInit + 14,
            child: _EtaChip(eta: _etaText, distance: _distText),
          ),

        // ── Map controls ───────────────────────────────────────────────
        if (_mapReady)
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).size.height * sheetInit + 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapBtn(
                  onTap: _fitBoth,
                  child: const Icon(
                    Icons.center_focus_strong,
                    color: kTextDark,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                _MapBtn(
                  onTap: () => setState(() => _cameraLocked = !_cameraLocked),
                  child: Icon(
                    _cameraLocked
                        ? Icons.my_location
                        : Icons.location_searching,
                    color: _cameraLocked ? _kBlue : kTextGray,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

        // ── Status chip top-right ──────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_StatusChip(status: status)],
            ),
          ),
        ),

        // ── Animated status banner (slides in from top on status change) ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          top: _bannerVisible ? 72.0 : -90.0,
          left: 12,
          right: 12,
          child:
              _bannerMsg != null
                  ? _StatusBanner(
                    message: _bannerMsg!,
                    color: _bannerColor,
                    icon: _bannerIcon,
                  )
                  : const SizedBox.shrink(),
        ),

        // ── Draggable bottom sheet ─────────────────────────────────────
        DraggableScrollableSheet(
          key: ValueKey(status),
          initialChildSize: sheetInit,
          minChildSize: sheetMin,
          maxChildSize: sheetMax,
          builder:
              (ctx, scrollCtrl) => Container(
                decoration: const BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: isFinding
                    ? _FindingSheet(
                        scrollCtrl: scrollCtrl,
                        address: _provider.pickupAddress,
                        onCancel: _onCancel,
                      )
                    : isProposed
                    ? _WaitingForCollectorSheet(
                        scrollCtrl: scrollCtrl,
                        provider: _provider,
                        onCancel: _onCancel,
                      )
                    : isAssigned
                    ? _ProposedSheet(
                        scrollCtrl: scrollCtrl,
                        provider: _provider,
                        etaText: _etaText,
                        distText: _distText,
                        paying: _paying,
                        onAcceptAndPay: _onAcceptAndPay,
                        onSkip: _onSkipCollector,
                        onCancel: _onCancel,
                      )
                    : _TrackingSheet(
                        scrollCtrl: scrollCtrl,
                        status: status,
                        provider: _provider,
                        etaText: _etaText,
                        distText: _distText,
                        isArrived: isArrived,
                        onConfirmComplete: _onConfirmComplete,
                        onCancel: _onCancel,
                      ),
              ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET STATES
// ══════════════════════════════════════════════════════════════════════════════

// ── Finding sheet ─────────────────────────────────────────────────────────────
class _FindingSheet extends StatefulWidget {
  final ScrollController scrollCtrl;
  final String address;
  final VoidCallback onCancel;
  const _FindingSheet({
    required this.scrollCtrl,
    required this.address,
    required this.onCancel,
  });

  @override
  State<_FindingSheet> createState() => _FindingSheetState();
}

class _FindingSheetState extends State<_FindingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: widget.scrollCtrl,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    children: [
      const SizedBox(height: 10),
      _Handle(),
      const SizedBox(height: 22),
      Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder:
                (_, child) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kPrimary.withValues(
                      alpha: 0.1 + 0.15 * _pulse.value,
                    ),
                  ),
                  child: child,
                ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: kPrimary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finding a Collector',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Matching with the nearest available collector…',
                  style: TextStyle(fontSize: 12, color: kTextGray),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: kPrimary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.address,
                style: const TextStyle(fontSize: 13, color: kTextDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: widget.onCancel,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Cancel Request',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
    ],
  );
}

// ── Waiting-for-collector sheet ────────────────────────────────────────────────
// Shown when status == 'proposed': system matched a collector, waiting for
// the collector to ACCEPT in their app before we show the customer a payment.
class _WaitingForCollectorSheet extends StatefulWidget {
  final ScrollController scrollCtrl;
  final AppProvider provider;
  final VoidCallback onCancel;
  const _WaitingForCollectorSheet({
    required this.scrollCtrl,
    required this.provider,
    required this.onCancel,
  });

  @override
  State<_WaitingForCollectorSheet> createState() =>
      _WaitingForCollectorSheetState();
}

class _WaitingForCollectorSheetState extends State<_WaitingForCollectorSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collector = widget.provider.proposedCollector;
    return ListView(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 10),
        _Handle(),
        const SizedBox(height: 22),
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimary.withValues(alpha: 0.1 + 0.15 * _pulse.value),
                ),
                child: child,
              ),
              child: const Center(
                child: Icon(Icons.person_search, color: kPrimary, size: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Collector Matched!',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Waiting for the collector to confirm…',
                    style: TextStyle(fontSize: 12, color: kTextGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (collector != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kLightGreen,
                  child: Text(
                    (collector['name'] as String).isNotEmpty
                        ? (collector['name'] as String)[0]
                        : 'C',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collector['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        collector['vehicle'] as String,
                        style: const TextStyle(fontSize: 12, color: kTextGray),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 15),
                    const SizedBox(width: 3),
                    Text(
                      parseDouble(collector['rating']).toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: kTextDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: kPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.provider.pickupAddress,
                  style: const TextStyle(fontSize: 13, color: kTextDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel Request',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Proposed sheet (shown when collector has ACCEPTED → status == 'assigned') ──
class _ProposedSheet extends StatelessWidget {
  final ScrollController scrollCtrl;
  final AppProvider provider;
  final String etaText;
  final String distText;
  final bool paying;
  final VoidCallback onAcceptAndPay;
  final VoidCallback onSkip;
  final VoidCallback onCancel;

  const _ProposedSheet({
    required this.scrollCtrl,
    required this.provider,
    required this.etaText,
    required this.distText,
    required this.paying,
    required this.onAcceptAndPay,
    required this.onSkip,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final collector = provider.proposedCollector;
    if (collector == null) {
      return _FindingSheet(
        scrollCtrl: scrollCtrl,
        address: provider.pickupAddress,
        onCancel: onCancel,
      );
    }
    final name = collector['name'] as String;
    final vehicle = collector['vehicle'] as String;
    final rating = parseDouble(collector['rating']);
    final phone = collector['phone'] as String;
    final dist = parseDouble(collector['distanceKm']);
    final price = provider.proposedPrice;
    final initial = name.isNotEmpty ? name[0] : 'C';

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 10),
        _Handle(),
        const SizedBox(height: 8),
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: kLightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: kPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collector Confirmed!',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  Text(
                    'Review details and complete your payment',
                    style: TextStyle(fontSize: 12, color: kTextGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ETA strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _InfoPill(icon: Icons.access_time, value: etaText, label: 'ETA'),
              Container(
                width: 1,
                height: 32,
                color: _kBlue.withValues(alpha: 0.2),
              ),
              _InfoPill(
                icon: Icons.social_distance_outlined,
                value: distText,
                label: 'Distance',
              ),
              Container(
                width: 1,
                height: 32,
                color: _kBlue.withValues(alpha: 0.2),
              ),
              _InfoPill(
                icon: Icons.payments_outlined,
                value: '$kCurrency $price',
                label: 'Total',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Collector card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(14),
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
              CircleAvatar(
                radius: 26,
                backgroundColor: kLightGreen,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicle,
                      style: const TextStyle(fontSize: 12, color: kTextGray),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${dist.toStringAsFixed(1)} km away',
                      style: const TextStyle(fontSize: 12, color: kTextGray),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: kTextDark,
                        ),
                      ),
                    ],
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _MapBtn(
                      onTap: () => callPhone(phone),
                      child: const Icon(Icons.phone, color: kPrimary, size: 18),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Confirm & Pay button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: paying ? null : onAcceptAndPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              disabledBackgroundColor: kPrimary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: paying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Confirm & Pay  ·  $kCurrency $price',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        // Find another
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: paying ? null : onSkip,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: kTextGray.withValues(alpha: 0.5),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Find Another Collector',
              style: TextStyle(
                color: kTextGray,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Cancel
        TextButton(
          onPressed: paying ? null : onCancel,
          child: const Text(
            'Cancel Request',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Tracking sheet (assigned/on_way/arrived) ───────────────────────────────────
class _TrackingSheet extends StatelessWidget {
  final ScrollController scrollCtrl;
  final String? status;
  final AppProvider provider;
  final String etaText;
  final String distText;
  final bool isArrived;
  final VoidCallback onConfirmComplete;
  final VoidCallback onCancel;

  const _TrackingSheet({
    required this.scrollCtrl,
    required this.status,
    required this.provider,
    required this.etaText,
    required this.distText,
    required this.isArrived,
    required this.onConfirmComplete,
    required this.onCancel,
  });

  int get _completedSteps => switch (status) {
    'assigned' => 2,
    'on_way' => 3,
    'arrived' => 4,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final active = provider.activeRequest;
    final profile = active?['collector_profile'] as Map<String, dynamic>?;
    final name = (active?['collector_name'] as String?) ?? 'Collector';
    final vehicle = (profile?['vehicle_type'] as String?) ?? 'Vehicle';
    final rating = parseDouble(profile?['rating']);
    final initial = name.isNotEmpty ? name[0] : 'C';

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 10),
        _Handle(),
        const SizedBox(height: 18),
        _StatusHeader(status: status),
        const SizedBox(height: 14),
        _ProgressBar(completed: _completedSteps),
        const SizedBox(height: 14),
        if (!isArrived)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: kPrimary),
                const SizedBox(width: 6),
                Text(
                  etaText,
                  style: const TextStyle(color: kTextGray, fontSize: 13),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.social_distance_outlined,
                  size: 16,
                  color: kPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  distText,
                  style: const TextStyle(color: kTextGray, fontSize: 13),
                ),
              ],
            ),
          ),
        // Collector info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(14),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: kLightGreen,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: kTextDark,
                      ),
                    ),
                    Text(
                      vehicle,
                      style: const TextStyle(fontSize: 12, color: kTextGray),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 15),
                  const SizedBox(width: 3),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: kTextDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isArrived)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onConfirmComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirm Pickup Complete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cancel Pickup',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ── Mobile Money payment bottom sheet ──────────────────────────────────────────
class _PaymentSheet extends StatefulWidget {
  final int price;
  final String defaultPhone;
  final void Function(String phone) onPay;
  const _PaymentSheet({
    required this.price,
    required this.defaultPhone,
    required this.onPay,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.defaultPhone);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Handle(),
              const SizedBox(height: 16),
              const Text(
                'Pay with Mobile Money',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total: $kCurrency ${widget.price}',
                style: const TextStyle(fontSize: 14, color: kTextGray),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will receive a USSD prompt on your phone. Approve it to complete payment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextGray, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'MoMo Number',
                  hintText: '0552779311',
                  prefixIcon: const Icon(Icons.phone_android, color: kPrimary),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => widget.onPay(_phoneCtrl.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Pay  $kCurrency ${widget.price}',
                    style: const TextStyle(
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
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _StatusHeader extends StatelessWidget {
  final String? status;
  const _StatusHeader({this.status});

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, color) = switch (status) {
      'finding' => (
        'Finding a Collector',
        'Searching nearby collectors…',
        Icons.search,
        kTextGray,
      ),
      'assigned' => (
        'Collector Assigned',
        'Your collector is preparing to leave.',
        Icons.check_circle,
        kPrimary,
      ),
      'on_way' => (
        'Collector En Route',
        'Your collector is heading to you.',
        Icons.local_shipping,
        _kBlue,
      ),
      'arrived' => (
        'Collector Arrived!',
        'Your collector is at the pickup point.',
        Icons.location_on,
        Colors.orange,
      ),
      _ => (
        'Live Tracking',
        'Real-time updates active.',
        Icons.gps_fixed,
        kPrimary,
      ),
    };
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kTextDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: kTextGray),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int completed;
  const _ProgressBar({required this.completed});

  static const _steps = ['Placed', 'Assigned', 'En Route', 'Arrived', 'Done'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length, (i) {
        final done = i < completed;
        final active = i == completed - 1;
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 4,
                color: done ? kPrimary : Colors.grey.shade200,
              ),
              const SizedBox(height: 4),
              if (active)
                Text(
                  _steps[i],
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip({this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'finding' => ('Searching…', kTextGray),
      'proposed' => ('Proposed', const Color(0xFF9C27B0)),
      'assigned' => ('Assigned', kPrimary),
      'on_way' => ('En Route', _kBlue),
      'arrived' => ('Arrived', Colors.orange),
      _ => ('Live', kPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated status banner ────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  const _StatusBanner({
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtaChip extends StatelessWidget {
  final String eta;
  final String distance;
  const _EtaChip({required this.eta, required this.distance});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _kBlue,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _kBlue.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_shipping, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(
          '$eta  ·  $distance',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _InfoPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _kBlue),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: kTextGray)),
    ],
  );
}

class _MapBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _MapBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.13), blurRadius: 8),
        ],
      ),
      child: Center(child: child),
    ),
  );
}

// ── No Request card ────────────────────────────────────────────────────────────
class _NoRequestCard extends StatelessWidget {
  const _NoRequestCard();

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.pushNamed(context, '/request'),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🌿 Eco Pickup',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Schedule a\nWaste Pickup',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fast, reliable & eco-friendly collection',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Request Now',
                              style: TextStyle(
                                color: Color(0xFF1B5E20),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, color: Color(0xFF1B5E20), size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 38),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Quick Action card ──────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Waste Type card ────────────────────────────────────────────────────────────
class _WasteTypeCard extends StatelessWidget {
  final Map<String, dynamic> wasteType;
  final VoidCallback onTap;
  const _WasteTypeCard({required this.wasteType, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = wasteType['color'] as Color;
    final icon = wasteType['icon'] as IconData;
    final price = parseInt(wasteType['price']);
    final name = wasteType['name'] as String;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 13),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$kCurrency $price',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

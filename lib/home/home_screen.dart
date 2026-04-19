import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../constants/api_constants.dart';
import '../providers/user_provider.dart';

import 'history.dart';
import 'profile_screen.dart';
import 'request.dart';
import 'schedule_pickup.dart';
import 'reports.dart';
import 'notification.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _dataRefreshTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  Map<String, dynamic>? _homeData;
  bool _isLoading = true;
  bool _isMapInitialized = false;
  final MapController _mapController = MapController();
  bool _locationServiceEnabled = true;
  LatLng? _currentGpsPos;
  String? _currentAddress;
  DateTime? _lastServerUpdate;

  @override
  void initState() {
    super.initState();

    // Redirect to login if not authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (!userProvider.isAuthenticated ||
          userProvider.authData?['access'] == null) {
        // Replace 'const LoginPage()' with your actual login screen class name
        // Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
        debugPrint("User not authenticated. Redirect to login required.");
        return;
      }

      _fetchHomeData().then((_) {
        _initLocationTracking();
      });

      _dataRefreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (t) => _fetchHomeData(),
      );
    });
  }

  @override
  void dispose() {
    _dataRefreshTimer?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _locationServiceEnabled = false);
      }
      if (mounted) _showLocationServiceDialog();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showLocationServiceDialog(isPermanent: true);
      return;
    }

    // Get immediate position to fix map alignment instantly
    Position initialPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    if (mounted) {
      setState(() => _locationServiceEnabled = true);
    }
    if (mounted) _handleNewPosition(initialPosition);

    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0, // Set to 0 to ensure continuous location updates
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_handleNewPosition);
  }

  void _showLocationServiceDialog({bool isPermanent = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF132314),
            title: const Text(
              "Location Required",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              isPermanent
                  ? "Location permissions are permanently denied. Please enable them in app settings to find collectors."
                  : "WastePick needs your location to coordinate real-time pickups. Please turn on location services.",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Maybe Later",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5ED5A8),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  isPermanent
                      ? Geolocator.openAppSettings()
                      : Geolocator.openLocationSettings();
                },
                child: Text(
                  isPermanent ? "Open Settings" : "Enable GPS",
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
    );
  }

  void _handleNewPosition(Position position) {
    if (mounted) {
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentGpsPos = newPos;
      });

      final activeRequests =
          _homeData?['data']['recent_collection_requests'] ?? [];

      // Move camera if it's the first lock and no active pickup is overriding the view
      // Or if the distance changed significantly (e.g., emulator location switch)
      if (activeRequests.isEmpty) {
        double distance =
            _currentGpsPos == null
                ? 0
                : Geolocator.distanceBetween(
                  _currentGpsPos!.latitude,
                  _currentGpsPos!.longitude,
                  newPos.latitude,
                  newPos.longitude,
                );

        if (!_isMapInitialized || distance > 100) {
          _mapController.move(newPos, 18.0);
        }
        _isMapInitialized = true;
      }

      _updateServerLocation(position);
    }
  }

  Future<void> _updateServerLocation(Position pos) async {
    // Both tracking endpoints now run every 2 seconds as requested
    final now = DateTime.now();
    if (_lastServerUpdate != null &&
        now.difference(_lastServerUpdate!).inSeconds < 2) {
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userProfile = _homeData?['data']['user_profile'];
    final String? accessToken = userProvider.authData?['access'];

    if (accessToken == null) return;

    String placeName = "";
    String landMark = "";

    try {
      // Use geocoding to get the human-readable address (Map Data)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // Extract actual values from map data
        // New York
        placeName = p.locality ?? p.subAdministrativeArea ?? "";
        // Central Park
        landMark = p.name ?? p.thoroughfare ?? "";

        if (mounted) setState(() => _currentAddress = placeName);
      }
    } catch (e) {
      debugPrint("Reverse Geocoding Error: $e");
    }

    try {
      // 1. Hit the Coordinate Tracking Endpoint
      final trackResponse = await http.post(
        Uri.parse(ApiConstants.trackLocation),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": pos.latitude,
          "longitude": pos.longitude,
        }),
      );
      debugPrint("Track Sync Status: ${trackResponse.statusCode}");

      // 2. Hit the Detailed Location Endpoint
      // Changed to PATCH because the 405 error indicates the server rejects POST for this update operation.
      final locationResponse = await http.patch(
        Uri.parse(ApiConstants.userLocation),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": pos.latitude,
          "longitude": pos.longitude,
          // Submit actual map values
          "place_name": placeName,
          "land_mark": landMark,
        }),
      );
      debugPrint("Location Sync Status: ${locationResponse.statusCode}");

      _lastServerUpdate = now;
    } catch (e) {
      debugPrint("API Sync Error: $e");
    }
  }

  Future<void> _fetchHomeData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final url = Uri.parse(ApiConstants.homeData);

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${userProvider.authData?['access']}",
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _homeData = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Home Data Fetch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: accentGreen)),
      );
    }

    if (!_locationServiceEnabled) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, color: Colors.white24, size: 80),
                const SizedBox(height: 20),
                const Text(
                  "Location Services Disabled",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Turn on location services to find collectors closer to you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _initLocationTracking,
                  style: ElevatedButton.styleFrom(backgroundColor: accentGreen),
                  child: const Text(
                    "Enable GPS",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeRequests =
        _homeData?['data']['recent_collection_requests'] ?? [];
    final binTypes = _homeData?['wast_bin_type'] ?? [];
    final unreadCount = _homeData?['unread_notification_count'] ?? 0;
    final Map<String, dynamic>? userProfile =
        _homeData?['data']['user_profile'];
    bool isTracking = activeRequests.isNotEmpty;
    bool hasLocationData = true;

    // Centering Logic
    LatLng mapFocus;
    if (isTracking) {
      hasLocationData = true;
      mapFocus = LatLng(
        double.tryParse(activeRequests[0]['customer']['latitude'].toString()) ??
            0.0,
        double.tryParse(
              activeRequests[0]['customer']['longitude'].toString(),
            ) ??
            0.0,
      );
    } else if (_currentGpsPos != null) {
      hasLocationData = true;
      mapFocus = _currentGpsPos!;
    } else if (userProfile != null &&
        userProfile['latitude'] != null &&
        userProfile['longitude'] != null) {
      hasLocationData = true;
      // Case C: Fallback to Profile Coords from API
      mapFocus = LatLng(
        double.tryParse(userProfile['latitude'].toString()) ?? 0.0,
        double.tryParse(userProfile['longitude'].toString()) ?? 0.0,
      );
    } else {
      // Absolute fallback if everything else fails
      hasLocationData = false;
      mapFocus = const LatLng(0.0, 0.0);
    }

    // Ensure map moves to focus if it's the first time data is available
    if (!_isMapInitialized &&
        (isTracking || _currentGpsPos != null || userProfile != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(mapFocus, 18.0);
          setState(() => _isMapInitialized = true);
        }
      });
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: mapFocus, initialZoom: 18.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // User Agent is required by OSM Tile Usage Policy
                  userAgentPackageName: 'com.wastmobile.app',
                ),
                MarkerLayer(
                  markers: [
                    if (_currentGpsPos != null)
                      Marker(
                        point: _currentGpsPos!,
                        width: 40,
                        height: 40,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 18,
                            ),
                            const Icon(
                              Icons.circle,
                              color: Colors.blueAccent,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    if (isTracking) ...[
                      Marker(
                        point: LatLng(
                          double.tryParse(
                                activeRequests[0]['customer']['latitude']
                                    .toString(),
                              ) ??
                              0.0,
                          double.tryParse(
                                activeRequests[0]['customer']['longitude']
                                    .toString(),
                              ) ??
                              0.0,
                        ),
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 50,
                        ),
                      ),
                      Marker(
                        point: LatLng(
                          double.tryParse(
                                activeRequests[0]['collector']['latitude']
                                    .toString(),
                              ) ??
                              0.0,
                          double.tryParse(
                                activeRequests[0]['collector']['longitude']
                                    .toString(),
                              ) ??
                              0.0,
                        ),
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.green,
                          size: 45,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                      bgColor.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Recenter Button
          if (_currentGpsPos != null)
            Positioned(
              right: 20,
              bottom:
                  isTracking ? 240 : 340, // Adjust based on which UI is visible
              child: FloatingActionButton(
                mini: true,
                backgroundColor: cardColor,
                child: const Icon(Icons.my_location, color: accentGreen),
                onPressed: () {
                  _mapController.move(_currentGpsPos!, 18.0);
                },
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(unreadCount, isTracking, userProfile),
                const Spacer(),
                if (isTracking)
                  _buildTrackingOverlay(
                    activeRequests[0],
                    binTypes,
                    cardColor,
                    accentGreen,
                  )
                else
                  _buildStandardHomeView(binTypes, cardColor, accentGreen),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, bgColor, accentGreen),
    );
  }

  Widget _buildTopBar(int count, bool tracking, Map<String, dynamic>? profile) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tracking ? "LIVE TRACKING" : "WASTEPICK",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _currentAddress ??
                    profile?['address'] ??
                    "Locating Position...",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          _buildNotificationIcon(count),
        ],
      ),
    );
  }

  Widget _buildTrackingOverlay(
    Map<String, dynamic> request,
    List binTypes,
    Color cardColor,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.location_on, color: Colors.blueAccent),
            ),
            title: Text(
              request['address'] ?? "Pickup Point",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              "Status: ${request['status']}",
              style: const TextStyle(color: Colors.greenAccent),
            ),
            trailing: Text(
              "${request['distance_km']} km",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                _buildCompactIcon(
                  Icons.delete_outline,
                  "Request",
                  const Color(0xFF4CAF50),
                  const RequestPickupPage(),
                ),
                _buildCompactIcon(
                  Icons.calendar_month,
                  "Schedule",
                  const Color(0xFF2196F3),
                  const SchedulePickupPage(),
                ),
                _buildCompactIcon(
                  Icons.history,
                  "History",
                  Colors.white70,
                  const ServiceHistoryPage(),
                ),
                ...binTypes
                    .map<Widget>(
                      (bin) => _buildCompactIcon(
                        Icons.delete_sweep,
                        bin['name'],
                        accent,
                        null,
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardHomeView(List binTypes, Color cardColor, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _buildActionBtn(
                "Request",
                Icons.delete,
                cardColor,
                Colors.green,
                const RequestPickupPage(),
              ),
              _buildActionBtn(
                "Schedule",
                Icons.event,
                cardColor,
                Colors.blue,
                const SchedulePickupPage(),
              ),
              _buildActionBtn(
                "History",
                Icons.history,
                cardColor,
                Colors.orange,
                const ServiceHistoryPage(),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            "Available Bins",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  binTypes
                      .map<Widget>(
                        (bin) => _buildWasteTypeCard(
                          bin['name'],
                          "GH₵ ${bin['base_price']}",
                          accent,
                          cardColor,
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteTypeCard(
    String title,
    String price,
    Color accent,
    Color bg,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(18),
      width: 140,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.delete_sweep, color: accent, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color bg,
    Color iconColor,
    Widget target,
  ) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => target),
          ),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactIcon(
    IconData icon,
    String label,
    Color color,
    Widget? target,
  ) {
    return GestureDetector(
      onTap: () {
        if (target != null)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => target),
          );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 25),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white10,
              radius: 22,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(int count) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationPage()),
          ),
      child: Stack(
        children: [
          const Icon(Icons.notifications_none, color: Colors.white, size: 30),
          if (count > 0)
            Positioned(
              right: 0,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.red,
                child: Text(
                  "$count",
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, Color bg, Color activeColor) {
    return BottomNavigationBar(
      backgroundColor: bg,
      selectedItemColor: activeColor,
      unselectedItemColor: Colors.white30,
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 1)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ServiceHistoryPage()),
          );
        if (index == 2)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}

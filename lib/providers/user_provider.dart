import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/app_config.dart';
import '../widgets/profile_avatar.dart';
import '../services/notification_service.dart';
import '../constants/api_constants.dart';
import '../utils/parse_utils.dart';

class AppProvider with ChangeNotifier {
  // ── Auth state ─────────────────────────────────────────────────────────────
  bool _isLoggedIn = false;
  bool _isCollector = false;
  bool _isAdmin = false;
  bool _isInvestor = false;
  Map<String, dynamic>? _currentUser;

  bool get isAuthenticated => _isLoggedIn;
  bool get isCollector => _isCollector;
  bool get isAdmin => _isAdmin;
  bool get isInvestor => _isInvestor;
  bool get isSuperAdmin =>
      (_currentUser?['role'] as String?) == 'super_admin' ||
      (_currentUser?['is_super_admin'] as bool? ?? false);
  Map<String, dynamic>? get currentUser => _currentUser;

  void setCurrentUser(Map<String, dynamic> user) {
    _currentUser = user;
    final role = user['role'] as String? ?? 'customer';
    _isLoggedIn = true;
    _isCollector = role == 'collector';
    _isAdmin = role == 'admin' || role == 'super_admin';
    _isInvestor = role == 'investor';
    notifyListeners();
    // Load active request immediately on every customer authentication (login or restart)
    if (role == 'customer' && _activeRequest == null && !_activeRequestLoading) {
      _loadActiveRequest();
    }
  }

  Future<void> initialize() async {
    final hasToken = await ApiService.hasTokens();
    if (!hasToken) return;
    try {
      final data = await ApiService.get(ApiConstants.me);
      setCurrentUser(data);
      if (data['role'] == 'customer' && data['profile_image'] == null) {
        try {
          final profile = await ApiService.get(ApiConstants.customerProfileUpdate);
          if (profile['profile_image'] != null) {
            mergeProfileImage(profile['profile_image'] as String);
          }
        } catch (_) {}
      }
    } catch (_) {
      await ApiService.clearTokens();
    }
  }

  Future<void> _loadActiveRequest() async {
    if (_activeRequestLoading) return;
    _activeRequestLoading = true;
    try {
      final data = await ApiService.get(ApiConstants.customerActiveRequest);
      final req = data['active_request'];
      if (req == null) {
        _activeRequestLoading = false;
        return;
      }
      _activeRequest = req as Map<String, dynamic>;
      _selectedWasteType = (_activeRequest!['waste_type'] as String?) ?? 'general';
      _pickupAddress    = (_activeRequest!['pickup_address'] as String?) ?? '';
      _selectedWastePrice = parseInt(_activeRequest!['price'], 20);
      final s = requestStatus;
      if (s != null && s != 'completed' && s != 'cancelled') {
        _lastPolledStatus = s;
        _startPolling();
        _syncLocationsFromActiveRequest();
      }
      notifyListeners();
    } catch (_) {}
    _activeRequestLoading = false;
  }

  void login() { _isLoggedIn = true; _isCollector = false; _isAdmin = false; _isInvestor = false; notifyListeners(); }
  void loginAsCollector() { _isLoggedIn = true; _isCollector = true; _isAdmin = false; _isInvestor = false; notifyListeners(); }
  void loginAsAdmin() { _isLoggedIn = true; _isCollector = false; _isAdmin = true; _isInvestor = false; notifyListeners(); }

  Future<void> loginAdmin(String email, String password) async {
    try {
      final data = await ApiService.post(
        ApiConstants.adminLogin,
        {'email': email, 'password': password},
        authenticated: false,
      );
      final tokens = data['tokens'] as Map<String, dynamic>;
      await ApiService.saveTokens(
        access: tokens['access'] as String,
        refresh: tokens['refresh'] as String,
      );
      setCurrentUser(data['user'] as Map<String, dynamic>);
      loginAsAdmin();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    try {
      final data = await ApiService.put(ApiConstants.me, fields);
      setCurrentUser(data);
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> logout() async {
    final refresh = await ApiService.getRefreshToken();
    try {
      if (refresh != null) await ApiService.post(ApiConstants.logout, {'refresh': refresh});
    } catch (_) {}
    await ApiService.clearTokens();
    _isLoggedIn = false;
    _isCollector = false;
    _isAdmin = false;
    _isInvestor = false;
    _currentUser = null;
    _pollTimer?.cancel();
    _activeRequest = null;
    _activeRequestLoading = false;
    _selectedBinTypeId = null;
    _selectedBinName = '';
    _selectedWastePrice = 0;
    _pickupAddress = '';
    _collectorOnline = false;
    _incomingRequestTimer?.cancel();
    _incomingRequest = null;
    _collectorLocation = _defaultCollectorStart;
    _collectorProfile = null;
    _collectorEarnings = null;
    _historyLoaded = false;
    _history = [];
    NotificationService.reset();
    notifyListeners();
  }

  // ── User display helpers ───────────────────────────────────────────────────
  String get displayName {
    if (_currentUser == null) return 'User';
    final full = (_currentUser!['full_name'] ?? '') as String;
    if (full.isNotEmpty) return full;
    final first = (_currentUser!['first_name'] ?? '') as String;
    return first.isNotEmpty ? first : 'User';
  }

  String get displayInitial => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

  String? get profileImageUrl {
    final profile = _currentUser?['profile'] as Map<String, dynamic>?;
    final collectorUrl = _collectorProfile?['profile_image'] as String?;
    final url = (profile?['profile_image']
        ?? _currentUser?['profile_image']
        ?? collectorUrl) as String?;
    if (url == null || url.isEmpty) return null;
    final resolved = url.startsWith('http') ? url : '${AppConfig.baseUrl}$url';
    final stamp = _profileImageVersion;
    return stamp > 0 ? '$resolved?v=$stamp' : resolved;
  }

  int _profileImageVersion = 0;

  void mergeProfileImage(String? url) {
    if (url == null || url.isEmpty) return;
    _profileImageVersion = DateTime.now().millisecondsSinceEpoch;
    _currentUser ??= {};
    final resolved = url.startsWith('http') ? url : '${AppConfig.baseUrl}$url';
    _currentUser!['profile_image'] = resolved;
    if (_collectorProfile != null) {
      _collectorProfile!['profile_image'] = resolved;
    }
    SslImageLoader.bustCache(resolved);
    notifyListeners();
  }

  Future<void> refreshProfileImageFromServer() async {
    try {
      final Map<String, dynamic> data;
      if (_isAdmin) {
        data = await ApiService.get(ApiConstants.adminProfile);
      } else if (_isCollector) {
        data = await ApiService.get(ApiConstants.collectorProfile);
      } else if (_isInvestor) {
        data = await ApiService.get(ApiConstants.investorProfile);
      } else {
        data = await ApiService.get(ApiConstants.customerProfileUpdate);
      }
      final image = data['profile_image'] as String?;
      if (image != null && image.isNotEmpty) {
        mergeProfileImage(image);
      }
    } catch (_) {}
  }

  // Sekondi-Takoradi service area — keep defaults aligned with home map.
  static const LatLng _kServiceCenter = LatLng(4.9016, -1.7574);
  static const LatLng _defaultCustomerLocation = _kServiceCenter;
  static const LatLng _defaultCollectorStart = LatLng(4.9120, -1.7600);

  LatLng _customerLocation = _defaultCustomerLocation;
  LatLng _collectorLocation = _defaultCollectorStart;

  LatLng get customerLocation => _customerLocation;

  void setCustomerLocation(LatLng loc) {
    _customerLocation = loc;
    notifyListeners();
  }

  void _syncLocationsFromActiveRequest() {
    if (_activeRequest == null) return;
    final pLat = parseDoubleOrNull(_activeRequest!['pickup_lat']);
    final pLng = parseDoubleOrNull(_activeRequest!['pickup_lng']);
    if (pLat != null && pLng != null) {
      _customerLocation = LatLng(pLat, pLng);
    }
    final profile = _activeRequest!['collector_profile'] as Map<String, dynamic>?;
    if (profile != null) {
      final cLat = parseDoubleOrNull(profile['current_lat']);
      final cLng = parseDoubleOrNull(profile['current_lng']);
      if (cLat != null && cLng != null) {
        _collectorLocation = LatLng(cLat, cLng);
      }
    }
  }

  double _calcDistanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  double _toRad(double d) => d * math.pi / 180;

  // ── Waste types — from API, fallback hardcoded ─────────────────────────────
  List<Map<String, dynamic>> _wasteTypesFromApi = [];

  List<Map<String, dynamic>> get wasteTypes =>
      _wasteTypesFromApi.isNotEmpty ? _wasteTypesFromApi : _fallbackWasteTypes;

  static List<Map<String, dynamic>> _makeBins(List<List<dynamic>> rows) => rows
      .map((r) => {
            'id': null,
            'name': r[0] as String,
            'display_name': r[1] as String,
            'price': r[2] as int,
            'description': r[3] as String,
          })
      .toList();

  static final List<Map<String, dynamic>> _fallbackWasteTypes = [
    {
      'name': 'general', 'label': 'General Waste',
      'sub': 'Household and everyday waste',
      'icon': Icons.delete_outline, 'color': const Color(0xFF757575),
      'bin_types': _makeBins([
        ['small',  'Small Bin',  20, 'Up to 20 litres'],
        ['medium', 'Medium Bin', 35, 'Up to 60 litres'],
        ['large',  'Large Bin',  55, 'Up to 120 litres'],
      ]),
    },
    {
      'name': 'recyclable', 'label': 'Recyclable',
      'sub': 'Paper, plastic, glass, metal',
      'icon': Icons.recycling, 'color': const Color(0xFF1565C0),
      'bin_types': _makeBins([
        ['small',  'Small Bin',  18, 'Up to 20 litres'],
        ['medium', 'Medium Bin', 30, 'Up to 60 litres'],
        ['large',  'Large Bin',  45, 'Up to 120 litres'],
      ]),
    },
    {
      'name': 'organic', 'label': 'Organic / Compost',
      'sub': 'Food scraps and garden waste',
      'icon': Icons.eco, 'color': const Color(0xFF2E7D32),
      'bin_types': _makeBins([
        ['small',  'Small Bin',  15, 'Up to 20 litres'],
        ['medium', 'Medium Bin', 25, 'Up to 60 litres'],
        ['large',  'Large Bin',  40, 'Up to 120 litres'],
      ]),
    },
    {
      'name': 'hazardous', 'label': 'Hazardous',
      'sub': 'Chemicals, batteries, e-waste',
      'icon': Icons.science_outlined, 'color': const Color(0xFFE65100),
      'bin_types': _makeBins([
        ['standard', 'Standard Pack',    55,  'Up to 10 kg'],
        ['large',    'Large Pack',        85,  'Up to 25 kg'],
        ['special',  'Special Disposal', 120, 'Bulk/special'],
      ]),
    },
  ];

  Future<void> fetchWasteTypes() async {
    try {
      final data = await ApiService.get(ApiConstants.wasteTypes);
      final raw = data['data'] ?? data['results'];
      if (raw == null) return;
      _wasteTypesFromApi = (raw as List<dynamic>).map((t) {
        final m = t as Map<String, dynamic>;
        final binsRaw = (m['bin_types'] as List?) ?? [];
        return {
          'name': m['key'] as String,
          'label': m['label'] as String,
          'sub': m['description'] as String,
          'icon': _iconFromName(m['icon'] as String? ?? ''),
          'color': _colorFromHex(m['color_hex'] as String? ?? '#757575'),
          'bin_types': binsRaw.map((b) {
            final bm = b as Map<String, dynamic>;
            return {
              'id': (bm['id'] as num).toInt(),
              'name': bm['name'] as String,
              'display_name': bm['display_name'] as String,
              'price': parseInt(bm['price']),
              'description': (bm['description'] as String?) ?? '',
            };
          }).toList(),
        };
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'recycling':        return Icons.recycling;
      case 'eco':              return Icons.eco;
      case 'science_outlined': return Icons.science_outlined;
      default:                 return Icons.delete_outline;
    }
  }

  Color _colorFromHex(String hex) {
    try {
      final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
      return Color(0xFF000000 | value);
    } catch (_) {
      return const Color(0xFF757575);
    }
  }

  // ── Customer active request ─────────────────────────────────────────────────
  Map<String, dynamic>? _activeRequest;
  bool _activeRequestLoading = false;
  Timer? _pollTimer;

  Map<String, dynamic>? get activeRequest => _activeRequest;
  String? get requestStatus => _activeRequest?['status'] as String?;
  bool get hasActiveRequest =>
      _activeRequest != null &&
      requestStatus != 'completed' &&
      requestStatus != 'cancelled';

  // Tracking is only "active" (map + WS route) once the collector is moving.
  // 'assigned' = collector accepted, customer needs to pay — not tracking yet.
  bool get isTrackingActive {
    final s = requestStatus;
    return s == 'on_way' || s == 'arrived';
  }

  // True when the collector has confirmed (assigned) OR is already on the way.
  bool get collectorConfirmed {
    final s = requestStatus;
    return s == 'assigned' || s == 'on_way' || s == 'arrived';
  }

  Map<String, dynamic>? get proposedCollector {
    final s = requestStatus;
    // Show collector card for both 'assigned' (collector accepted) and
    // 'proposed' (for manual-grab flow where customer confirms).
    if (s != 'proposed' && s != 'assigned') return null;
    final profile = _activeRequest?['collector_profile'] as Map<String, dynamic>?;
    if (profile == null) return null;
    final lat = parseDoubleOrNull(profile['current_lat']);
    final lng = parseDoubleOrNull(profile['current_lng']);
    double distKm = 2.0;
    if (lat != null && lng != null) {
      distKm = _calcDistanceKm(LatLng(lat, lng), _customerLocation);
    }
    return {
      'name':       (_activeRequest!['collector_name'] ?? 'Collector') as String,
      'vehicle':    (profile['vehicle_type'] ?? 'Vehicle') as String,
      'rating':     parseDouble(profile['rating']),
      'phone':      (_activeRequest!['collector_phone'] ?? '') as String,
      'distanceKm': distKm,
    };
  }

  int get proposedPrice {
    if (_activeRequest == null) return dynamicPrice;
    final price = _activeRequest!['price'];
    return price != null ? parseInt(price, dynamicPrice) : dynamicPrice;
  }

  Map<String, dynamic> get priceBreakdown {
    final breakdown = _activeRequest?['price_breakdown'] as Map<String, dynamic>?;
    if (breakdown != null) return breakdown;
    return {
      'base_price': _activeRequest?['base_price'] ?? '0',
      'distance_km': parseDouble(_activeRequest?['distance_km']) ,
      'distance_fee': _activeRequest?['distance_fee'] ?? '0',
      'total': _activeRequest?['price'] ?? '0',
    };
  }

  LatLng get collectorLocation {
    final profile = _activeRequest?['collector_profile'] as Map<String, dynamic>?;
    if (profile != null) {
      final lat = parseDoubleOrNull(profile['current_lat']);
      final lng = parseDoubleOrNull(profile['current_lng']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return _collectorLocation;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollActiveRequest(),
    );
  }

  String? _lastPolledStatus;

  Future<void> _pollActiveRequest() async {
    try {
      final data = await ApiService.get(ApiConstants.customerActiveRequest);
      final req = data['active_request'];
      if (req == null) {
        final wasActive = _activeRequest != null;
        _activeRequest = null;
        _pollTimer?.cancel();
        _lastPolledStatus = null;
        if (wasActive) notifyListeners();
        return;
      }
      _activeRequest = req as Map<String, dynamic>;
      final newStatus = requestStatus;
      _syncLocationsFromActiveRequest();
      // Fire local notification on status change
      if (newStatus != _lastPolledStatus) {
        final collectorName = _activeRequest?['collector_name'] as String?;
        NotificationService.onRequestStatusChanged(newStatus, collectorName: collectorName);
        _lastPolledStatus = newStatus;
      }
      if (requestStatus == 'completed' || requestStatus == 'cancelled') {
        _pollTimer?.cancel();
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── Payment state ──────────────────────────────────────────────────────────
  String? _pendingPaymentType;
  String? get pendingPaymentType => _pendingPaymentType;
  bool get paymentConfirmed =>
      (_activeRequest?['payment_status'] as String?) == 'confirmed';

  Future<void> recordPayment(String paymentType, {int? paymentMethodId}) async {
    throw Exception('Use payWithMoMo() for Mobile Money payments.');
  }

  /// Initiate Coded Pay MoMo and poll until confirmed or timeout (~2 min).
  Future<void> payWithMoMo(String phoneNumber) async {
    final id = _activeRequest?['id'] as int?;
    if (id == null) return;
    final phone = phoneNumber.trim();
    if (phone.isEmpty) {
      throw Exception('Enter your Mobile Money number.');
    }

    try {
      final init = await ApiService.post(ApiConstants.recordPayment(id), {
        'phone_number': phone,
      });
      final pickup = init['pickup'];
      if (pickup is Map<String, dynamic>) {
        _activeRequest = pickup;
        notifyListeners();
      }

      for (var attempt = 0; attempt < 24; attempt++) {
        await Future.delayed(const Duration(seconds: 5));
        final result = await ApiService.get(ApiConstants.verifyMoMoPayment(id));
        final codedStatus = (result['coded_pay_status'] as String?)?.toLowerCase();
        final payStatus = (result['payment_status'] as String?)?.toLowerCase();
        final updated = result['pickup'];
        if (updated is Map<String, dynamic>) {
          _activeRequest = updated;
        }

        if (payStatus == 'confirmed' || codedStatus == 'success') {
          _pendingPaymentType = 'mobile_money';
          notifyListeners();
          return;
        }
        if (codedStatus == 'failed' || codedStatus == 'decline') {
          final msg = result['message'] as String? ?? 'Payment failed. Try again.';
          notifyListeners();
          throw Exception(msg);
        }
      }
      throw Exception(
        'Payment timed out. Approve the USSD prompt on your phone and try again.',
      );
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Customer request flow ──────────────────────────────────────────────────
  String _selectedWasteType = 'general';
  int _selectedWastePrice = 0;
  int? _selectedBinTypeId;
  String _selectedBinName = '';
  String _pickupAddress = '';

  String get selectedWasteType => _selectedWasteType;
  int get selectedWastePrice => _selectedWastePrice;
  int? get selectedBinTypeId => _selectedBinTypeId;
  String get selectedBinName => _selectedBinName;
  String get pickupAddress => _pickupAddress;

  int get dynamicPrice => _selectedWastePrice;

  /// Distance to assigned/proposed collector, or 0 before matching.
  double get collectorDistanceKm {
    final km = parseDoubleOrNull(_activeRequest?['distance_km']);
    if (km != null && km > 0) return km;
    final proposed = proposedCollector;
    if (proposed != null) return parseDouble(proposed['distanceKm']);
    return 0;
  }

  void setPickupDetails(
    String wasteType,
    int binPrice,
    String address, {
    int? binTypeId,
    String binTypeName = '',
  }) {
    _selectedWasteType = wasteType;
    _selectedWastePrice = binPrice;
    _selectedBinTypeId = binTypeId;
    _selectedBinName = binTypeName;
    _pickupAddress = address;
    notifyListeners();
  }

  Future<void> startRequest() async {
    _activeRequest = {
      'status': 'finding',
      'waste_type': _selectedWasteType,
      'pickup_address': _pickupAddress,
      'price': _selectedWastePrice,
    };
    _lastPolledStatus = 'finding';
    _pollTimer?.cancel();
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'waste_type': _selectedWasteType.toLowerCase(),
        'pickup_address': _pickupAddress,
        'pickup_lat': _customerLocation.latitude,
        'pickup_lng': _customerLocation.longitude,
      };
      if (_selectedBinTypeId != null) body['bin_type'] = _selectedBinTypeId;
      final data = await ApiService.post(ApiConstants.customerRequests, body);
      _activeRequest = data;
      _syncLocationsFromActiveRequest();
      _startPolling();
      notifyListeners();
    } on ApiException catch (e) {
      _activeRequest = null;
      notifyListeners();
      throw Exception(e.message);
    } catch (_) {
      _activeRequest = null;
      notifyListeners();
      throw Exception('Unable to connect. Check your connection.');
    }
  }

  Future<void> acceptProposedCollector() async {
    if (requestStatus != 'proposed') return;
    final id = _activeRequest?['id'] as int?;
    if (id == null) return;
    try {
      final data = await ApiService.post(ApiConstants.acceptCollector(id), {});
      _activeRequest = data;
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  // Called from the customer "Confirm & Pay" button — MoMo only via Coded Pay.
  Future<void> payAndAccept(String phoneNumber) async {
    await payWithMoMo(phoneNumber);
  }

  Future<void> skipProposedCollector() async {
    if (requestStatus != 'proposed') return;
    final id = _activeRequest?['id'] as int?;
    if (id == null) return;
    _activeRequest = Map.of(_activeRequest!)..['status'] = 'finding';
    notifyListeners();
    try {
      final data = await ApiService.post(ApiConstants.skipCollector(id), {});
      _activeRequest = data;
      notifyListeners();
    } on ApiException catch (e) {
      _pollTimer?.cancel();
      _startPolling();
      throw Exception(e.message);
    }
  }

  Future<void> cancelRequest() async {
    final id = _activeRequest?['id'] as int?;
    _pollTimer?.cancel();
    _activeRequest = null;
    _lastPolledStatus = null;
    _collectorLocation = _defaultCollectorStart;
    NotificationService.reset();
    notifyListeners();
    if (id != null) {
      try { await ApiService.post(ApiConstants.cancelRequest(id), {}); } catch (_) {}
    }
  }

  void completeRequest() {
    _pollTimer?.cancel();
    if (_activeRequest != null) {
      _activeRequest = Map.of(_activeRequest!)..['status'] = 'completed';
      _addToHistory();
    }
    notifyListeners();
  }

  Future<void> rateCompletedPickup(int rating, {String? comment}) async {
    final id = _activeRequest?['id'] as int?;
    if (id == null || rating < 1) return;
    try {
      await ApiService.post(ApiConstants.rateRequest(id), {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
    } on ApiException catch (_) {
      // Rating is best-effort after pickup completes
    }
  }

  void _addToHistory() {
    if (_activeRequest == null) return;
    _history.insert(0, {
      'wasteType':  _selectedWasteType,
      'address':    _pickupAddress,
      'date':       _formatDate(DateTime.now()),
      'amount':     proposedPrice,
      'status':     'Completed',
    });
  }

  void clearCompletedRequest() {
    _activeRequest = null;
    _lastPolledStatus = null;
    _pendingPaymentType = null;
    _collectorLocation = _defaultCollectorStart;
    NotificationService.reset();
    notifyListeners();
  }

  void markCollectorArrived() {
    if (_activeRequest != null) {
      _activeRequest = Map.of(_activeRequest!)..['status'] = 'arrived';
    }
    _collectorLocation = _customerLocation;
    notifyListeners();
  }

  // ── History (from API) ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  bool _historyLoaded = false;

  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  Future<void> fetchHistory({bool force = false}) async {
    if (_historyLoaded && !force) return;
    try {
      final data = await ApiService.get(ApiConstants.customerRequests);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _history = raw.map((r) {
          final m = r as Map<String, dynamic>;
          return {
            'id':        m['id'],
            'wasteType': m['waste_type'] ?? '',
            'address':   m['pickup_address'] ?? '',
            'date':      _formatApiDate(m['completed_at'] as String? ?? m['created_at'] as String? ?? ''),
            'amount':    parseInt(m['price']),
            'status':    _localizeStatus((m['status'] as String?) ?? ''),
          };
        }).toList();
        _historyLoaded = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  String _localizeStatus(String s) {
    switch (s) {
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      case 'on_way':
      case 'arrived':
      case 'assigned': return 'Active';
      case 'finding':  return 'Searching';
      case 'proposed': return 'Proposed';
      default:         return s;
    }
  }

  List<Map<String, dynamic>> getFilteredHistory(String filter) {
    if (filter == 'All') return List.unmodifiable(_history);
    return _history
        .where((item) => item['status'].toString().toLowerCase() == filter.toLowerCase())
        .toList();
  }

  // ── Notifications (from API) ───────────────────────────────────────────────
  int _unreadNotifications = 0;
  int get unreadNotifications => _unreadNotifications;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  Future<void> fetchNotifications() async {
    try {
      final data = await ApiService.get(ApiConstants.customerNotifications);
      _unreadNotifications = parseInt(data['unread_count']);
      final raw = data['notifications'];
      if (raw is List) {
        _notifications = raw.map((n) {
          final m = n as Map<String, dynamic>;
          return {
            'id':      m['id'],
            'title':   m['title'] ?? '',
            'message': m['body'] ?? '',
            'time':    _formatApiDate(m['created_at'] as String? ?? ''),
            'read':    m['is_read'] ?? false,
            'type':    m['notification_type'] ?? 'system',
          };
        }).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await ApiService.post(ApiConstants.customerMarkAllRead, {});
      _unreadNotifications = 0;
      for (final n in _notifications) { n['read'] = true; }
      notifyListeners();
    } catch (_) {}
  }

  // ── Saved addresses (from API) ─────────────────────────────────────────────
  List<Map<String, dynamic>> _savedAddresses = [];
  List<Map<String, dynamic>> get savedAddresses => List.unmodifiable(_savedAddresses);

  Future<void> fetchAddresses() async {
    try {
      final data = await ApiService.get(ApiConstants.customerAddresses);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _savedAddresses = raw.map((a) {
          final m = a as Map<String, dynamic>;
          return {
            'id':      m['id'],
            'label':   m['label'] ?? '',
            'address': m['address'] ?? '',
            'lat':     parseDoubleOrNull(m['lat']),
            'lng':     parseDoubleOrNull(m['lng']),
          };
        }).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> addAddress(Map<String, dynamic> address) async {
    try {
      final data = await ApiService.post(ApiConstants.customerAddresses, address);
      _savedAddresses.insert(0, data);
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> deleteAddress(int id) async {
    try {
      await ApiService.delete(ApiConstants.deleteAddress(id));
      _savedAddresses.removeWhere((a) => a['id'] == id);
      notifyListeners();
    } catch (_) {}
  }

  // ── Payment methods (from API) ─────────────────────────────────────────────
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> get paymentMethods => List.unmodifiable(_paymentMethods);

  Future<void> fetchPaymentMethods() async {
    try {
      final data = await ApiService.get(ApiConstants.customerPaymentMethods);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _paymentMethods = raw.map((p) {
          final m = p as Map<String, dynamic>;
          return {
            'id':        m['id'],
            'type':      'Mobile Money',
            'provider':  m['provider'] ?? '',
            'number':    m['number'] ?? '',
            'isDefault': m['is_default'] ?? false,
          };
        }).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> addPaymentMethod(Map<String, dynamic> method) async {
    try {
      final body = {
        'payment_type': 'mobile_money',
        'provider': method['provider'] ?? 'MTN',
        'number': method['number'] ?? '',
        'is_default': method['isDefault'] ?? false,
      };
      final data = await ApiService.post(ApiConstants.customerPaymentMethods, body);
      _paymentMethods.insert(0, {
        'id':        data['id'],
        'type':      'Mobile Money',
        'provider':  data['provider'] ?? '',
        'number':    data['number'] ?? '',
        'isDefault': data['is_default'] ?? false,
      });
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> deletePaymentMethod(int id) async {
    try {
      await ApiService.delete(ApiConstants.deletePaymentMethod(id));
      _paymentMethods.removeWhere((m) => m['id'] == id);
      notifyListeners();
    } catch (_) {}
  }

  // ── Scheduled pickups (from API) ───────────────────────────────────────────
  List<Map<String, dynamic>> _scheduledPickups = [];
  List<Map<String, dynamic>> get scheduledPickups => List.unmodifiable(_scheduledPickups);

  Future<void> fetchSchedules() async {
    try {
      final data = await ApiService.get(ApiConstants.customerSchedules);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _scheduledPickups = raw.map((s) => s as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> addSchedule(Map<String, dynamic> schedule) async {
    try {
      final data = await ApiService.post(ApiConstants.customerSchedules, schedule);
      _scheduledPickups.insert(0, data);
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> cancelSchedule(int id) async {
    try {
      await ApiService.delete(ApiConstants.cancelSchedule(id));
      _scheduledPickups.removeWhere((s) => s['id'] == id);
      notifyListeners();
    } catch (_) {}
  }

  // ── Dumping reports (from API) ─────────────────────────────────────────────
  // ignore: prefer_final_fields — mutated by addDumpingReport
  List<Map<String, dynamic>> _dumpingReports = [];
  List<Map<String, dynamic>> get dumpingReports => List.unmodifiable(_dumpingReports);

  Future<void> addDumpingReport(Map<String, dynamic> report) async {
    try {
      final data = await ApiService.post(ApiConstants.customerReports, report);
      _dumpingReports.insert(0, _mapDumpingReport(data));
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> fetchDumpingReports() async {
    try {
      final data = await ApiService.get(ApiConstants.customerReports);
      final raw = data['results'] ?? data['data'] ?? data;
      if (raw is List) {
        _dumpingReports = raw
            .map((r) => _mapDumpingReport(r as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Map<String, dynamic> _mapDumpingReport(Map<String, dynamic> m) {
    final status = (m['status'] as String?) ?? 'pending';
    return {
      'id': m['id'],
      'location': m['location'] ?? m['address'] ?? '',
      'description': m['description'] ?? '',
      'date': _formatApiDate(m['created_at'] as String? ?? ''),
      'status': status == 'resolved' ? 'Investigated' : 'Pending',
    };
  }

  // ── Collector — profile & earnings ────────────────────────────────────────
  Map<String, dynamic>? _collectorProfile;
  Map<String, dynamic>? _collectorEarnings;

  Map<String, dynamic>? get collectorProfile    => _collectorProfile;
  Map<String, dynamic>? get collectorEarnings   => _collectorEarnings;

  bool _collectorOnline = false;
  bool get collectorOnline => _collectorOnline;

  double get accountBalance  => (_collectorEarnings?['account_balance'] as String?).toDouble();
  double get todayEarnings   => (_collectorEarnings?['today_earnings'] as String?).toDouble();
  double get weeklyEarnings  => (_collectorEarnings?['weekly_earnings'] as String?).toDouble();
  double get totalEarnings   => (_collectorEarnings?['total_earnings'] as String?).toDouble();
  double get unpaidCommission => (_collectorEarnings?['unpaid_commission'] as String?).toDouble();
  int    get totalCollections => (_collectorEarnings?['total_collections'] as num?)?.toInt() ?? 0;
  int    get creditScore => (_collectorEarnings?['credit_score'] as num?)?.toInt() ?? (_collectorProfile?['credit_score'] as num?)?.toInt() ?? 100;
  bool get collectorApproved => (_collectorProfile?['is_approved'] as bool?) ?? false;

  Future<void> fetchCollectorProfile() async {
    try {
      _collectorProfile = await ApiService.get(ApiConstants.collectorProfile);
      _collectorOnline  = (_collectorProfile?['is_online'] as bool?) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchCollectorEarnings() async {
    try {
      _collectorEarnings = await ApiService.get(ApiConstants.collectorEarnings);
      final tx = _collectorEarnings?['recent_transactions'];
      if (tx is List) {
        _recentTransactions = tx.map((t) {
          final m = t as Map<String, dynamic>;
          return {
            'id': m['id'],
            'type': m['type'] ?? '',
            'amount': parseDouble(m['amount']),
            'description': m['description'] ?? '',
            'status': m['status'] ?? '',
            'date': _formatApiDate(m['created_at'] as String? ?? ''),
          };
        }).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchCollectorPaymentMethods() async {
    try {
      final data = await ApiService.get(ApiConstants.collectorPaymentMethods);
      final raw = data['payment_methods'] as List? ?? [];
      _collectorPaymentMethods = raw.map((p) => p as Map<String, dynamic>).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addCollectorPaymentMethod({
    required String paymentType,
    required String number,
    String provider = '',
  }) async {
    await ApiService.post(ApiConstants.collectorPaymentMethods, {
      'payment_type': paymentType,
      'number': number,
      'provider': provider,
    });
    await fetchCollectorPaymentMethods();
  }

  Future<String> requestWithdrawal(double amount, {int? paymentMethodId}) async {
    final body = <String, dynamic>{'amount': amount};
    if (paymentMethodId != null) body['payment_method_id'] = paymentMethodId;
    try {
      final data = await ApiService.post(ApiConstants.collectorWithdraw, body);
      await fetchCollectorEarnings();
      return (data['message'] as String?) ?? 'Withdrawal submitted.';
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> markCollectorNotificationRead(int id) async {
    await ApiService.post(ApiConstants.collectorNotificationRead(id), {});
    final idx = _collectorNotifications.indexWhere((n) => n['id'] == id);
    if (idx >= 0 && !(_collectorNotifications[idx]['read'] as bool? ?? false)) {
      _collectorNotifications[idx]['read'] = true;
      _collectorUnreadNotifications = (_collectorUnreadNotifications - 1).clamp(0, 999);
      notifyListeners();
    }
  }

  Future<void> uploadCollectorProfilePhoto(String filePath) async {
    await ApiService.putMultipart(
      ApiConstants.collectorProfile,
      {},
      imageFile: File(filePath),
    );
    await refreshProfileImageFromServer();
  }

  // ── Collector — toggle online ──────────────────────────────────────────────
  DateTime? _lastLocationPush;
  LatLng? _lastPushedLocation;

  Future<void> pushCollectorLocation(double lat, double lng) async {
    if (!_collectorOnline) return;

    final now = DateTime.now();
    if (_lastLocationPush != null &&
        _lastPushedLocation != null &&
        now.difference(_lastLocationPush!) < const Duration(seconds: 12)) {
      const earthRadius = 6371000.0;
      final dLat = (lat - _lastPushedLocation!.latitude) * math.pi / 180;
      final dLng = (lng - _lastPushedLocation!.longitude) * math.pi / 180;
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_lastPushedLocation!.latitude * math.pi / 180) *
              math.cos(lat * math.pi / 180) *
              math.sin(dLng / 2) *
              math.sin(dLng / 2);
      final distM = earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      if (distM < 20) return;
    }

    try {
      await ApiService.put(ApiConstants.collectorLocation, {
        'lat': lat,
        'lng': lng,
      });
      _collectorLocation = LatLng(lat, lng);
      _lastLocationPush = now;
      _lastPushedLocation = LatLng(lat, lng);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleCollectorOnline({double? lat, double? lng}) async {
    try {
      final body = <String, dynamic>{};
      if (lat != null && lng != null) {
        body['lat'] = lat;
        body['lng'] = lng;
      }
      final data = await ApiService.post(ApiConstants.collectorToggleOnline, body);
      _collectorOnline = (data['is_online'] as bool?) ?? !_collectorOnline;
      if (_collectorOnline) {
        _startIncomingPoll();
      } else {
        _stopIncomingPoll();
        _incomingRequest = null;
        _lastLocationPush = null;
        _lastPushedLocation = null;
      }
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Collector — update profile ─────────────────────────────────────────────
  Future<void> updateCollectorProfile(Map<String, dynamic> fields) async {
    try {
      await ApiService.put(ApiConstants.collectorProfile, fields);
      await fetchCollectorProfile();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Collector — notifications ──────────────────────────────────────────────
  List<Map<String, dynamic>> _collectorNotifications = [];
  int _collectorUnreadNotifications = 0;
  List<Map<String, dynamic>> get collectorNotifications => List.unmodifiable(_collectorNotifications);
  int get collectorUnreadNotifications => _collectorUnreadNotifications;

  Future<void> fetchCollectorNotifications() async {
    try {
      final data = await ApiService.get(ApiConstants.collectorNotifications);
      _collectorUnreadNotifications = parseInt(data['unread_count']);
      final raw = data['notifications'];
      if (raw is List) {
        _collectorNotifications = raw.map((n) {
          final m = n as Map<String, dynamic>;
          return {
            'id':      m['id'],
            'title':   m['title'] ?? '',
            'message': m['body'] ?? '',
            'time':    _formatApiDate(m['created_at'] as String? ?? ''),
            'read':    m['is_read'] ?? false,
            'type':    m['notification_type'] ?? 'system',
          };
        }).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllCollectorNotificationsRead() async {
    try {
      await ApiService.post(ApiConstants.collectorNotifications, {});
      _collectorUnreadNotifications = 0;
      for (final n in _collectorNotifications) { n['read'] = true; }
      notifyListeners();
    } catch (_) {}
  }

  // ── Collector — incoming (auto-matched) requests ───────────────────────────
  Map<String, dynamic>? _incomingRequest;
  Map<String, dynamic>? get incomingRequest => _incomingRequest;

  Timer? _incomingRequestTimer;
  Map<String, dynamic>? _lastIncoming;

  void _startIncomingPoll() {
    _incomingRequestTimer?.cancel();
    _incomingRequestTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollIncomingRequests();
    });
  }

  void _stopIncomingPoll() {
    _incomingRequestTimer?.cancel();
    _incomingRequestTimer = null;
  }

  Future<void> _pollIncomingRequests() async {
    if (!_collectorOnline) return;
    try {
      final data = await ApiService.get(ApiConstants.collectorIncoming);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first as Map<String, dynamic>;
        final previousId = _lastIncoming?['id'];
        final newId = first['id'];
        if (previousId != newId) {
          // New incoming request — fire local notification
          final customerName = first['customer_name'] as String?;
          NotificationService.onIncomingRequestChanged(hasNew: true, customerName: customerName);
        }
        _incomingRequest = _mapIncomingRequest(first);
        _lastIncoming    = first;
      } else {
        if (_incomingRequest != null) {
          NotificationService.onIncomingRequestChanged(hasNew: false);
        }
        _incomingRequest = null;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Maps snake_case API response to camelCase fields expected by
  /// the collector's _IncomingRequestSheet UI widget.
  Map<String, dynamic> _mapIncomingRequest(Map<String, dynamic> raw) {
    final pLat = parseDoubleOrNull(raw['pickup_lat']);
    final pLng = parseDoubleOrNull(raw['pickup_lng']);

    // Distance from the collector's stored location to the pickup point
    String distanceText = '—';
    if (pLat != null && pLng != null) {
      final cLat = parseDoubleOrNull(_collectorProfile?['current_lat']);
      final cLng = parseDoubleOrNull(_collectorProfile?['current_lng']);
      if (cLat != null && cLng != null) {
        final dist = _calcDistanceKm(LatLng(cLat, cLng), LatLng(pLat, pLng));
        distanceText = '${dist.toStringAsFixed(1)} km';
      }
    }

    // Human-readable time-ago from created_at
    String timeAgo = 'Just now';
    final createdAt = raw['created_at'] as String?;
    if (createdAt != null) {
      try {
        final diff = DateTime.now().difference(DateTime.parse(createdAt));
        if (diff.inMinutes >= 60) {
          timeAgo = '${diff.inHours} hr ago';
        } else if (diff.inMinutes >= 1) {
          timeAgo = '${diff.inMinutes} min ago';
        }
      } catch (_) {}
    }

    final cLat2 = parseDoubleOrNull(_collectorProfile?['current_lat']);
    final cLng2 = parseDoubleOrNull(_collectorProfile?['current_lng']);
    return {
      ...raw,
      'customerName':  (raw['customer_name'] ?? '') as String,
      'phone':         (raw['customer_phone'] ?? '') as String,
      'location':      (raw['pickup_address'] ?? '') as String,
      'distance':      distanceText,
      'wasteType':     (raw['waste_type'] ?? '') as String,
      'price':         parseInt(raw['price']),
      'timeAgo':       timeAgo,
      // Coordinates for route preview and tracking
      'pickup_lat':    pLat,
      'pickup_lng':    pLng,
      'pickupLat':     pLat,
      'pickupLng':     pLng,
      'collectorLat':  cLat2,
      'collectorLng':  cLng2,
    };
  }

  // ── Collector — accept incoming request ───────────────────────────────────
  Map<String, dynamic>? _activeCollectorRequest;
  Map<String, dynamic>? get activeCollectorRequest => _activeCollectorRequest;

  LatLng? get acceptedCustomerLocation {
    final lat = (_activeCollectorRequest?['pickup_lat'] as num?)?.toDouble();
    final lng = (_activeCollectorRequest?['pickup_lng'] as num?)?.toDouble();
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  Future<void> acceptRequest() async {
    if (_incomingRequest == null) return;
    final id = _incomingRequest!['id'] as int?;
    if (id == null) return;
    try {
      final data = await ApiService.post(ApiConstants.acceptRequest(id), {});
      _activeCollectorRequest = data;
      _incomingRequest = null;
      _lastIncoming = null;
      await fetchCollectorEarnings();
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> declineRequest() async {
    if (_incomingRequest == null) return;
    final id = _incomingRequest!['id'] as int?;
    if (id == null) return;
    try {
      await ApiService.post(ApiConstants.declineRequest(id), {});
    } catch (_) {}
    _incomingRequest = null;
    _lastIncoming = null;
    notifyListeners();
  }

  // ── Collector — job progression ────────────────────────────────────────────
  Future<void> markOnWay() async {
    final id = _activeCollectorRequest?['id'] as int?;
    if (id == null) return;
    try {
      final data = await ApiService.post(ApiConstants.markOnWay(id), {});
      _activeCollectorRequest = data;
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> markArrived() async {
    final id = _activeCollectorRequest?['id'] as int?;
    if (id == null) return;
    try {
      final data = await ApiService.post(ApiConstants.markArrived(id), {});
      _activeCollectorRequest = data;
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> completePickup() async {
    final id = _activeCollectorRequest?['id'] as int?;
    if (id == null) return;
    try {
      final data = await ApiService.post(ApiConstants.completePickup(id), {});
      _activeCollectorRequest = data;
      await fetchCollectorEarnings();
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Collector — history & withdrawals ─────────────────────────────────────
  List<Map<String, dynamic>> _collectorCollections = [];
  List<Map<String, dynamic>> get collectorCollections => List.unmodifiable(_collectorCollections);
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> get recentTransactions => List.unmodifiable(_recentTransactions);
  List<Map<String, dynamic>> _collectorPaymentMethods = [];
  List<Map<String, dynamic>> get collectorPaymentMethods => List.unmodifiable(_collectorPaymentMethods);

  Map<String, dynamic> _mapCollection(Map<String, dynamic> m) {
    return {
      'id': m['id'],
      'customerName': m['customer_name'] ?? '',
      'customerPhone': m['customer_phone'] ?? '',
      'location': m['pickup_address'] ?? '',
      'pickupLat': parseDoubleOrNull(m['pickup_lat']),
      'pickupLng': parseDoubleOrNull(m['pickup_lng']),
      'wasteType': m['waste_type'] ?? '',
      'price': parseInt(m['price']),
      'basePrice': parseInt(m['base_price']),
      'distanceKm': parseDouble(m['distance_km']),
      'distanceFee': parseDouble(m['distance_fee']),
      'paymentType': m['payment_type'] ?? '',
      'paymentStatus': m['payment_status'] ?? '',
      'rating': parseDoubleOrNull(m['customer_rating']),
      'ratingComment': m['rating_comment'] ?? '',
      'date': _formatApiDate(m['completed_at'] as String? ?? m['created_at'] as String? ?? ''),
      'completedAt': m['completed_at'] ?? m['created_at'],
      'status': 'Completed',
      'priceBreakdown': m['price_breakdown'],
    };
  }

  Future<void> fetchCollectorCollections({String period = 'all'}) async {
    try {
      final url = period == 'all'
          ? ApiConstants.collectorCollections
          : '${ApiConstants.collectorCollections}?period=$period';
      final data = await ApiService.get(url);
      final raw = data['results'] ?? data['data'] ?? data;
      if (raw is List) {
        _collectorCollections = raw
            .map((r) => _mapCollection(r as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> fetchCollectorCollectionDetail(int id) async {
    final data = await ApiService.get(ApiConstants.collectorCollection(id));
    return _mapCollection(data);
  }

  List<Map<String, dynamic>> _assignedSchedules = [];
  List<Map<String, dynamic>> get assignedSchedules => List.unmodifiable(_assignedSchedules);
  List<Map<String, dynamic>> _activeSchedules = [];
  List<Map<String, dynamic>> get activeSchedules => List.unmodifiable(_activeSchedules);
  List<Map<String, dynamic>> _completedSchedules = [];
  List<Map<String, dynamic>> get completedSchedules => List.unmodifiable(_completedSchedules);

  // Schedule confirmed by collector — shown as active job on home tab
  Map<String, dynamic>? _confirmedActiveSchedule;
  Map<String, dynamic>? get confirmedActiveSchedule => _confirmedActiveSchedule;

  void clearConfirmedSchedule() {
    _confirmedActiveSchedule = null;
    notifyListeners();
  }

  Future<void> fetchAssignedSchedules() async {
    try {
      final data = await ApiService.get(ApiConstants.collectorSchedules);
      List<dynamic> raw = data['results'] as List? ?? [];
      if (raw.isEmpty && data['upcoming'] is List) {
        raw = [
          ...(data['active'] as List? ?? []),
          ...(data['upcoming'] as List? ?? []),
          ...(data['completed'] as List? ?? []),
        ];
      } else if (raw.isEmpty) {
        raw = data['data'] as List? ?? [];
      }
      _activeSchedules = [];
      _completedSchedules = [];
      _assignedSchedules = raw.map((s) {
          final m = s as Map<String, dynamic>;
          final timeStr = (m['next_pickup_datetime'] ?? m['scheduled_time'] ??
              m['pickup_time'] ?? m['pickup_datetime'] ?? '') as String;
          DateTime? pickupDt;
          try {
            if (timeStr.isNotEmpty) pickupDt = DateTime.parse(timeStr).toLocal();
          } catch (_) {}
          final mapped = {
            ...m,
            'id':           m['id'],
            'customerName': (m['customer_name'] ?? m['customerName'] ?? 'Customer') as String,
            'customerPhone':(m['customer_phone'] ?? '') as String,
            'wasteType':    (m['waste_type']    ?? m['wasteType']    ?? 'General')  as String,
            'location':     (m['pickup_address']?? m['location']     ?? '')         as String,
            'pickupLat':    parseDoubleOrNull(m['pickup_lat']),
            'pickupLng':    parseDoubleOrNull(m['pickup_lng']),
            'price':        parseInt(m['price']),
            'pickupTime':   pickupDt?.toIso8601String() ?? timeStr,
            'scheduleStatus': m['schedule_status'] ?? 'upcoming',
            'secondsUntil': m['seconds_until_pickup'],
            'collectorConfirmed': m['collector_confirmed'] ?? false,
            'dayName':      pickupDt != null ? _dayName(pickupDt) : (m['dayName'] ?? ''),
            'date':         pickupDt != null ? _formatDate(pickupDt) : (m['date'] ?? ''),
            'time':         pickupDt != null ? _timeOnly(pickupDt)   : (m['time'] ?? ''),
          };
          final st = mapped['scheduleStatus'] as String;
          if (st == 'active') {
            _activeSchedules.add(mapped);
          } else if (st == 'completed') {
            _completedSchedules.add(mapped);
          }
          return mapped;
        }).toList();
        notifyListeners();
    } catch (_) {}
  }

  Future<void> confirmSchedulePickup(int scheduleId) async {
    try {
      await ApiService.post(ApiConstants.confirmSchedule(scheduleId), {});
      final idx = _assignedSchedules.indexWhere((s) => s['id'] == scheduleId);
      if (idx >= 0) {
        _confirmedActiveSchedule = Map<String, dynamic>.from(_assignedSchedules[idx]);
        _assignedSchedules.removeAt(idx);
      }
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  String _dayName(DateTime dt) {
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return days[dt.weekday - 1];
  }

  String _timeOnly(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  // ── Admin — dashboard & lists ──────────────────────────────────────────────
  Map<String, dynamic>? _adminDashboard;
  Map<String, dynamic>? get adminDashboard => _adminDashboard;

  int get adminTotalCustomers => (_adminDashboard?['total_customers'] as num?)?.toInt() ?? 0;
  double get adminTotalRevenue => (_adminDashboard?['total_revenue'] as num?)?.toDouble() ?? 0.0;
  int get adminActiveCollectors => (_adminDashboard?['active_collectors'] as num?)?.toInt() ?? 0;
  int get adminPendingPickups => (_adminDashboard?['pending_pickups'] as num?)?.toInt() ?? 0;

  Future<void> fetchAdminDashboard() async {
    try {
      _adminDashboard = await ApiService.get(ApiConstants.adminDashboard);
      notifyListeners();
    } catch (_) {}
  }

  List<Map<String, dynamic>> _adminCustomers = [];
  List<Map<String, dynamic>> get adminCustomers => List.unmodifiable(_adminCustomers);

  Future<void> fetchAdminCustomers() async {
    try {
      final data = await ApiService.get(ApiConstants.adminCustomers);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _adminCustomers = raw.map((c) => c as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _adminCollectors = [];
  List<Map<String, dynamic>> get adminCollectors => List.unmodifiable(_adminCollectors);

  Future<void> fetchAdminCollectors({String filter = 'all'}) async {
    try {
      final data = await ApiService.get('${ApiConstants.adminCollectors}?filter=$filter');
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _adminCollectors = raw.map((c) => c as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> approveCollector(int profileId) async {
    try {
      await ApiService.post(ApiConstants.approveCollector(profileId), {});
      final idx = _adminCollectors.indexWhere((c) => c['id'] == profileId);
      if (idx >= 0) _adminCollectors[idx]['is_approved'] = true;
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> declineCollector(int profileId, {String? reason}) async {
    try {
      await ApiService.post(
        ApiConstants.declineCollector(profileId),
        {'reason': reason ?? 'Your application has been declined.'},
      );
      _adminCollectors.removeWhere((c) => c['id'] == profileId);
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  List<Map<String, dynamic>> _adminSchedules = [];
  List<Map<String, dynamic>> get adminAllSchedules => List.unmodifiable(_adminSchedules);

  Future<void> fetchAdminSchedules() async {
    try {
      final data = await ApiService.get(ApiConstants.adminSchedules);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _adminSchedules = raw.map((s) => s as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> assignScheduleCollector(int scheduleId, int collectorUserId) async {
    try {
      await ApiService.put(ApiConstants.assignSchedule(scheduleId), {'collector_id': collectorUserId});
      await fetchAdminSchedules();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Map<String, dynamic>? _adminFinance;
  double get adminAvailableBalance   => (_adminFinance?['total_revenue'] as num?)?.toDouble() ?? 0.0;
  double get adminTotalPaidOut       => (_adminFinance?['total_paid_out'] as num?)?.toDouble() ?? 0.0;
  double get adminPendingPayoutsTotal {
    return _adminWithdrawals
        .where((w) => w['status'] == 'pending')
        .fold(0.0, (sum, w) => sum + ((w['amount'] as num?)?.toDouble() ?? 0.0));
  }

  Future<void> fetchAdminFinance() async {
    try {
      _adminFinance = await ApiService.get(ApiConstants.adminFinance);
      notifyListeners();
    } catch (_) {}
  }

  List<Map<String, dynamic>> _adminWithdrawals = [];
  List<Map<String, dynamic>> get withdrawalRequests => List.unmodifiable(_adminWithdrawals);

  Future<void> fetchAdminWithdrawals({String status = 'all'}) async {
    try {
      final data = await ApiService.get('${ApiConstants.adminWithdrawals}?status=$status');
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _adminWithdrawals = raw.map((w) => w as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> approveWithdrawal(int withdrawalId) async {
    try {
      await ApiService.post(ApiConstants.approveWithdrawal(withdrawalId), {});
      final idx = _adminWithdrawals.indexWhere((w) => w['id'] == withdrawalId);
      if (idx >= 0) _adminWithdrawals[idx]['status'] = 'approved';
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> declineWithdrawal(int withdrawalId) async {
    try {
      await ApiService.post(ApiConstants.declineWithdrawal(withdrawalId), {});
      final idx = _adminWithdrawals.indexWhere((w) => w['id'] == withdrawalId);
      if (idx >= 0) _adminWithdrawals[idx]['status'] = 'declined';
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  List<Map<String, dynamic>> _adminReports = [];
  List<Map<String, dynamic>> get adminReports => List.unmodifiable(_adminReports);

  Future<void> fetchAdminReports() async {
    try {
      final data = await ApiService.get(ApiConstants.adminReports);
      final raw = data['data'] ?? data['results'] ?? data;
      if (raw is List) {
        _adminReports = raw.map((r) => r as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> resolveReport(int reportId) async {
    try {
      await ApiService.post(ApiConstants.resolveReport(reportId), {});
      final idx = _adminReports.indexWhere((r) => r['id'] == reportId);
      if (idx >= 0) _adminReports[idx]['status'] = 'resolved';
      notifyListeners();
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDate(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatApiDate(String iso) {
    try {
      return _formatDate(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  // ── Super-Admin: Branch Management ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchBranches() async {
    final data = await ApiService.get(ApiConstants.superAdminBranches);
    final list = data is List ? data as List : (data['results'] as List? ?? []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createBranch({
    required String name,
    required String region,
    String country = 'Ghana',
    String address = '',
    required double lat,
    required double lng,
    double serviceRadiusKm = 50.0,
  }) async {
    return await ApiService.post(ApiConstants.superAdminBranches, {
      'name': name,
      'region': region,
      'country': country,
      'address': address,
      'lat': lat,
      'lng': lng,
      'service_radius_km': serviceRadiusKm,
    });
  }

  Future<void> updateBranch(int id, Map<String, dynamic> fields) async {
    await ApiService.put(ApiConstants.superAdminBranch(id), fields);
  }

  Future<void> deleteBranch(int id) async {
    await ApiService.delete(ApiConstants.superAdminBranch(id));
  }

  Future<List<Map<String, dynamic>>> fetchAdminUsers() async {
    final data = await ApiService.get(ApiConstants.superAdminAdmins);
    final list = data is List ? data as List : (data['results'] as List? ?? []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String firstName,
    required String lastName,
    required String phone,
    String email = '',
    required String password,
    int? branchId,
  }) async {
    return await ApiService.post(ApiConstants.superAdminAdmins, {
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'password': password,
      if (branchId != null) 'branch_id': branchId,
    });
  }

  Future<void> assignAdminBranch(int adminId, int? branchId) async {
    await ApiService.put(ApiConstants.superAdminAdmin(adminId), {
      'branch_id': branchId,
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _incomingRequestTimer?.cancel();
    super.dispose();
  }
}

// Extension to safely parse nullable String to double
extension _StringToDouble on String? {
  double toDouble() {
    if (this == null) return 0.0;
    return double.tryParse(this!) ?? 0.0;
  }
}

typedef UserProvider = AppProvider;

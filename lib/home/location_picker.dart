import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/app_config.dart';

const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

// Sekondi-Takoradi service area bounds (generous padding)
const _kStMinLat = 4.72;
const _kStMaxLat = 5.06;
const _kStMinLng = -1.98;
const _kStMaxLng = -1.48;

bool _isInSekondiTakoradi(double lat, double lng) =>
    lat >= _kStMinLat && lat <= _kStMaxLat &&
    lng >= _kStMinLng && lng <= _kStMaxLng;

bool looksLikeCoordinates(String value) {
  final trimmed = value.trim();
  return RegExp(r'^-?\d+\.\d+\s*,\s*-?\d+\.\d+$').hasMatch(trimmed);
}

Future<String> reverseGeocodeAddress(double lat, double lng) async {
  // Prefer backend geocoding (server API key, no mobile restrictions).
  try {
    final res = await ApiService.get(ApiConstants.geoReverse(lat, lng));
    final address = res['address'] as String?;
    if (address != null &&
        address.trim().isNotEmpty &&
        !looksLikeCoordinates(address)) {
      return address.trim();
    }
  } catch (_) {}

  // Direct Google Geocoding fallback.
  try {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng'
      '&region=gh'
      '&language=en'
      '&key=${AppConfig.googleMapsApiKey}',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (body['results'] as List?) ?? [];
      const preferred = [
        'street_address',
        'route',
        'premise',
        'subpremise',
        'neighborhood',
        'sublocality',
        'locality',
      ];
      for (final type in preferred) {
        for (final item in results) {
          final types = (item['types'] as List?)?.cast<String>() ?? [];
          if (types.contains(type)) {
            final address = item['formatted_address'] as String?;
            if (address != null && address.trim().isNotEmpty) {
              return address.trim();
            }
          }
        }
      }
      if (results.isNotEmpty) {
        final address = results[0]['formatted_address'] as String?;
        if (address != null && address.trim().isNotEmpty) {
          return address.trim();
        }
      }
    }
  } catch (_) {}

  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
  try {
    final res = await ApiService.get(ApiConstants.geoSearch(query));
    final raw = (res['results'] as List?) ?? [];
    return raw.map<Map<String, dynamic>>((item) {
      final map = item as Map<String, dynamic>;
      return {
        'address': map['address'] as String,
        'lat': (map['lat'] as num).toDouble(),
        'lng': (map['lng'] as num).toDouble(),
      };
    }).toList();
  } catch (_) {}

  // Direct geocode fallback if backend search fails.
  try {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(query)}'
      '&region=gh'
      '&components=country:GH'
      '&language=en'
      '&key=${AppConfig.googleMapsApiKey}',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? [];
    return results.take(8).map<Map<String, dynamic>>((item) {
      final loc = (item['geometry'] as Map)['location'] as Map;
      return {
        'address': item['formatted_address'] as String,
        'lat': (loc['lat'] as num).toDouble(),
        'lng': (loc['lng'] as num).toDouble(),
      };
    }).toList();
  } catch (_) {
    return [];
  }
}

Future<Map<String, dynamic>?> showLocationPicker(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationPickerSheet(),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _savedMatches = [];
  bool _searching = false;
  bool _gpsLoading = false;
  String? _gpsError;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _savedMatches = [];
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(trimmed),
    );
  }

  List<Map<String, dynamic>> _filterSavedAddresses(
    List<Map<String, dynamic>> saved,
    String query,
  ) {
    final q = query.toLowerCase();
    return saved.where((s) {
      final label = (s['label'] as String? ?? '').toLowerCase();
      final address = (s['address'] as String? ?? '').toLowerCase();
      return label.contains(q) || address.contains(q);
    }).toList();
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final provider = context.read<AppProvider>();
      final saved = _filterSavedAddresses(provider.savedAddresses, query);
      final google = await searchPlaces(query);
      if (!mounted) return;
      setState(() {
        _savedMatches = saved;
        _searchResults = google;
        if (google.isEmpty && saved.isEmpty) {
          _searchError = 'No places found. Try a street name, area, or landmark.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _searchError = 'Search failed. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectLocation(Map<String, dynamic> result) {
    final lat = (result['lat'] as num).toDouble();
    final lng = (result['lng'] as num).toDouble();
    if (!_isInSekondiTakoradi(lat, lng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WastePick is currently only available in Sekondi-Takoradi, Ghana. '
            'Please choose a location within the service area.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final address = result['address'] as String? ?? '';
    if (looksLikeCoordinates(address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resolve a street name. Try searching manually.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(context, result);
  }

  Future<void> _useGps() async {
    setState(() {
      _gpsLoading = true;
      _gpsError = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _gpsError = 'Location permission denied. Enable it in Settings.';
          _gpsLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      if (!_isInSekondiTakoradi(pos.latitude, pos.longitude)) {
        setState(() {
          _gpsError =
              'WastePick is currently only available in Sekondi-Takoradi, Ghana. '
              'Your GPS shows a location outside the service area. '
              'Please search for your pickup address manually.';
          _gpsLoading = false;
        });
        return;
      }

      final address = await reverseGeocodeAddress(pos.latitude, pos.longitude);
      if (!mounted) return;

      if (looksLikeCoordinates(address)) {
        setState(() {
          _gpsError =
              'Could not resolve your GPS to a street name. '
              'Please search for your area or landmark below.';
          _gpsLoading = false;
        });
        return;
      }

      Navigator.pop(context, {
        'address': address,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsError = 'Could not get location. Try again.';
          _gpsLoading = false;
        });
      }
    } finally {
      if (mounted && _gpsLoading) setState(() => _gpsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final saved = provider.savedAddresses;
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Set Pickup Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: _kTextDark),
                decoration: InputDecoration(
                  hintText: 'Search street, area, landmark…',
                  hintStyle:
                      const TextStyle(color: _kTextGray, fontSize: 14),
                  prefixIcon:
                      const Icon(Icons.search, color: _kPrimary, size: 22),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kPrimary,
                            ),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _kPrimary, width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _GpsTile(
                    loading: _gpsLoading,
                    error: _gpsError,
                    onTap: _gpsLoading ? null : _useGps,
                  ),
                  const SizedBox(height: 4),
                  if (isSearching) ...[
                    if (_savedMatches.isNotEmpty) ...[
                      const _SectionLabel('YOUR SAVED ADDRESSES'),
                      ..._savedMatches.map(
                        (s) {
                          final lat = (s['lat'] as double?) ??
                              provider.customerLocation.latitude;
                          final lng = (s['lng'] as double?) ??
                              provider.customerLocation.longitude;
                          return _LocationTile(
                            icon: s['label'] == 'Home'
                                ? Icons.home_outlined
                                : Icons.work_outline,
                            title: s['label'] as String,
                            subtitle: s['address'] as String,
                            onTap: () => _selectLocation({
                              'address': s['address'],
                              'lat': lat,
                              'lng': lng,
                            }),
                          );
                        },
                      ),
                    ],
                    if (_searchResults.isNotEmpty) ...[
                      const _SectionLabel('GOOGLE PLACES'),
                      ..._searchResults.map(
                        (r) => _LocationTile(
                          icon: Icons.location_on_outlined,
                          title: _shortAddress(r['address'] as String),
                          subtitle: r['address'] as String,
                          onTap: () => _selectLocation(r),
                        ),
                      ),
                    ],
                    if (_searchError != null &&
                        !_searching &&
                        _searchResults.isEmpty &&
                        _savedMatches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _searchError!,
                          style: const TextStyle(color: _kTextGray, fontSize: 13),
                        ),
                      ),
                  ] else ...[
                    const _SectionLabel('SAVED ADDRESSES'),
                    if (saved.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Search above for any place in Ghana, or save addresses from your profile.',
                          style: TextStyle(color: _kTextGray, fontSize: 13),
                        ),
                      )
                    else
                      ...saved.map(
                        (s) {
                          final lat = (s['lat'] as double?) ??
                              provider.customerLocation.latitude;
                          final lng = (s['lng'] as double?) ??
                              provider.customerLocation.longitude;
                          return _LocationTile(
                            icon: s['label'] == 'Home'
                                ? Icons.home_outlined
                                : Icons.work_outline,
                            title: s['label'] as String,
                            subtitle: s['address'] as String,
                            onTap: () => _selectLocation({
                              'address': s['address'],
                              'lat': lat,
                              'lng': lng,
                            }),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortAddress(String full) {
    final parts = full.split(',');
    return parts.take(2).join(',').trim();
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: _kTextGray,
            letterSpacing: 1.1,
          ),
        ),
      );
}

class _GpsTile extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback? onTap;

  const _GpsTile({required this.loading, this.error, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kLightGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPrimary,
                      ),
                    )
                  : const Icon(Icons.my_location, color: _kPrimary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Use my current location',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _kPrimary,
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          error!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.red),
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

class _LocationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LocationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kLightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _kPrimary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _kTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: _kTextGray),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: _kTextGray),
            ],
          ),
        ),
      );
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Hasil dari Location Picker
class LocationResult {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class LocationPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Default: Jakarta
  late LatLng _selectedLocation;
  String? _selectedAddress;
  bool _isSearching = false;
  List<_NominatimResult> _searchResults = [];
  Timer? _debounce;
  bool _showResults = false;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      widget.initialLatitude ?? -6.2088,
      widget.initialLongitude ?? 106.8456,
    );
    _reverseGeocode(_selectedLocation);
    _tryGetCurrentLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Coba ambil lokasi saat ini
  Future<void> _tryGetCurrentLocation({bool isUserAction = false}) async {
    if (isUserAction && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mencari lokasi saat ini...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (isUserAction && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS tidak aktif. Mohon nyalakan GPS Anda.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (isUserAction && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin akses lokasi ditolak.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (isUserAction && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin akses lokasi ditolak permanen.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (widget.initialLatitude == null || isUserAction) {
        // Auto-locate jika belum ada initial location ATAU jika ditekan user
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_selectedLocation, 16);
        _reverseGeocode(_selectedLocation);
      }
    } catch (e) {
      // Gagal ambil lokasi, pakai default
      if (isUserAction && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan lokasi: $e')),
        );
      }
    }
  }

  /// Reverse geocode: koordinat -> alamat
  Future<void> _reverseGeocode(LatLng location) async {
    setState(() => _isLoadingAddress = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'hadir.in/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _selectedAddress = data['display_name'] as String?;
        });
      }
    } catch (_) {
      // Ignore reverse geocode errors
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  /// Search lokasi via Nominatim
  Future<void> _searchLocation(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&countrycodes=id',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'hadir.in/1.0'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data
              .map(
                (item) => _NominatimResult(
                  displayName: item['display_name'] as String,
                  lat: double.parse(item['lat'] as String),
                  lon: double.parse(item['lon'] as String),
                ),
              )
              .toList();
          _showResults = _searchResults.isNotEmpty;
        });
      }
    } catch (_) {
      // Ignore search errors
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _searchLocation(query);
    });
  }

  void _onSelectSearchResult(_NominatimResult result) {
    final location = LatLng(result.lat, result.lon);
    setState(() {
      _selectedLocation = location;
      _selectedAddress = result.displayName;
      _searchController.text = '';
      _showResults = false;
      _searchResults = [];
    });
    _mapController.move(location, 16);
    FocusScope.of(context).unfocus();
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = null;
    });
    _reverseGeocode(location);
  }

  void _onConfirm() {
    Navigator.pop(
      context,
      LocationResult(
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        address: _selectedAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Stack(
          children: [
            // ─── Map ───
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 15,
                onTap: (_, point) => _onMapTap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.hadirin.app',
                  retinaMode: RetinaMode.isHighDensity(context),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 60,
                      height: 60,
                      child: const _AnimatedPin(),
                    ),
                  ],
                ),
              ],
            ),

            // ─── Top Bar: Back + Search ───
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 22,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Search bar
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Cari lokasi atau alamat...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF9CA3AF),
                              ),
                              prefixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF9CA3AF),
                                      size: 20,
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search results dropdown
                  if (_showResults)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
                          indent: 50,
                        ),
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            title: Text(
                              result.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF374151),
                                height: 1.4,
                              ),
                            ),
                            onTap: () => _onSelectSearchResult(result),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // ─── My Location Button ───
            Positioned(
              right: 16,
              bottom: 240,
              child: GestureDetector(
                onTap: () => _tryGetCurrentLocation(isUserAction: true),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
              ),
            ),

            // ─── Bottom Card ───
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lokasi Dipilih',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _isLoadingAddress
                                  ? Row(
                                      children: [
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Mencari alamat...',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _selectedAddress ??
                                          '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF6B7280),
                                        height: 1.4,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Coordinate badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Konfirmasi Lokasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated pin marker
class _AnimatedPin extends StatefulWidget {
  const _AnimatedPin();

  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounce = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _bounce.value), child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          // Shadow dot
          Container(
            width: 8,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Model for Nominatim search results
class _NominatimResult {
  final String displayName;
  final double lat;
  final double lon;

  _NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/api_config.dart';
import '../../../../core/widgets/brand_text.dart';

class SelfCheckInPage extends StatefulWidget {
  final String eventId;

  const SelfCheckInPage({super.key, required this.eventId});

  @override
  State<SelfCheckInPage> createState() => _SelfCheckInPageState();
}

class _SelfCheckInPageState extends State<SelfCheckInPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  XFile? _photo;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _successMessage;

  // Location state
  Position? _position;
  bool _isGettingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  /// Auto-fetch lokasi saat halaman dibuka
  Future<void> _fetchLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'GPS tidak aktif. Aktifkan lokasi di pengaturan HP.';
          _isGettingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Izin lokasi ditolak. Izinkan untuk bisa absen.';
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Izin lokasi diblokir permanen. Buka pengaturan HP untuk mengaktifkannya.';
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _position = position;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Gagal mengambil lokasi. Coba lagi.';
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() {
          _photo = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka kamera: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ambil foto wajah kamu dulu ya'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi GPS belum didapat. Tekan tombol refresh lokasi.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = FormData.fromMap({
        'name': _nameCtrl.text.trim(),
        'latitude': _position!.latitude,
        'longitude': _position!.longitude,
      });

      if (kIsWeb) {
        final bytes = await _photo!.readAsBytes();
        formData.files.add(
          MapEntry(
            'photo',
            MultipartFile.fromBytes(bytes, filename: _photo!.name),
          ),
        );
      } else {
        formData.files.add(
          MapEntry(
            'photo',
            await MultipartFile.fromFile(_photo!.path, filename: _photo!.name),
          ),
        );
      }

      final dio = Dio();
      String baseUrl = ApiConfig.apiUrl;
      if (kIsWeb) {
        // baseUrl = '/api';
      }

      final response = await dio.post(
        '$baseUrl/attendance/self-checkin/${widget.eventId}',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _successMessage = response.data['message'];
        });
      }
    } on DioException catch (e) {
      String msg = 'Gagal melakukan check-in';
      if (e.response != null && e.response!.data != null) {
        msg = e.response!.data['message'] ?? msg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_successMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Berhasil!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _successMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: const Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandText(fontSize: 20),
            SizedBox(width: 8),
            Text(
              'Check-in',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selamat Datang!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan isi form di bawah ini untuk absen mandiri.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // ─── Location Status Card ───
              _buildLocationCard(),
              const SizedBox(height: 24),

              // Nama Lengkap
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Pengambilan Foto
              Text(
                'Bukti Kehadiran (Foto Wajah)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 2,
                    ),
                  ),
                  child: _photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: kIsWeb
                              ? Image.network(_photo!.path, fit: BoxFit.cover)
                              : Image.file(
                                  File(_photo!.path),
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              size: 40,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sentuh untuk foto selfie',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Kirim & Check-in',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
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
    );
  }

  /// Card yang menampilkan status lokasi GPS peserta
  Widget _buildLocationCard() {
    Color cardColor;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;
    Widget? trailing;

    if (_isGettingLocation) {
      cardColor = const Color(0xFFEEF2FF);
      iconColor = const Color(0xFF2563EB);
      icon = Icons.my_location_rounded;
      title = 'Mengambil lokasi...';
      subtitle = 'Mohon tunggu sebentar';
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF2563EB),
        ),
      );
    } else if (_locationError != null) {
      cardColor = const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFEF4444);
      icon = Icons.location_off_rounded;
      title = 'Lokasi gagal';
      subtitle = _locationError!;
      trailing = GestureDetector(
        onTap: _fetchLocation,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 20,
            color: Color(0xFFEF4444),
          ),
        ),
      );
    } else if (_position != null) {
      cardColor = const Color(0xFFF0FDF4);
      iconColor = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
      title = 'Lokasi berhasil didapat';
      subtitle =
          '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}';
      trailing = GestureDetector(
        onTap: _fetchLocation,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 20,
            color: Color(0xFF10B981),
          ),
        ),
      );
    } else {
      cardColor = const Color(0xFFF3F4F6);
      iconColor = const Color(0xFF9CA3AF);
      icon = Icons.location_searching_rounded;
      title = 'Lokasi belum tersedia';
      subtitle = 'Klik refresh untuk mengambil ulang';
      trailing = GestureDetector(
        onTap: _fetchLocation,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF9CA3AF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 20,
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

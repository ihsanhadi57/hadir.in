import 'package:flutter/material.dart';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadir_in_app/core/widgets/brand_text.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/event_repository.dart';
import 'location_picker_page.dart';
import '../../../../core/constants/api_config.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _emailController = TextEditingController();
  final _repo = GetIt.instance<EventRepository>();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  String? _csvFileName;
  String? _csvFilePath;
  double? _latitude;
  double? _longitude;
  String? _locationAddress;
  String? _imagePath;
  String? _imageName;

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _onPickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _imageName = result.files.single.name;
        _imagePath = result.files.single.path;
      });
    }
  }

  void _onRemoveImage() {
    setState(() {
      _imageName = null;
      _imagePath = null;
    });
  }

  Future<void> _onPickCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _csvFileName = result.files.single.name;
        _csvFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _onDownloadTemplate() async {
    final uri = Uri.parse('${ApiConfig.apiUrl}/participants/template/csv');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal membuka browser', AppTheme.error);
    }
  }

  void _onRemoveCsv() {
    setState(() {
      _csvFileName = null;
      _csvFilePath = null;
    });
  }

  Future<void> _onSubmit({bool isDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnackBar('Pilih tanggalnya dulu ya', AppTheme.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dateTime = _selectedDate!;
      final combinedDate = _selectedTime != null
          ? DateTime(
              dateTime.year,
              dateTime.month,
              dateTime.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            )
          : dateTime;

      final createdEvent = await _repo.createEvent(
        name: _nameController.text.trim(),
        description: _venueController.text.trim(),
        contactEmail: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        date: combinedDate,
        latitude: _latitude,
        longitude: _longitude,
      );

      // ─── Upload Gambar Event (Jika Ada) ───
      if (_imagePath != null) {
        try {
          await _repo.uploadEventImage(createdEvent.id, _imagePath!);
        } catch (imgError) {
          debugPrint('Gagal upload gambar: $imgError');
        }
      }

      // Jika ada file CSV terlampir, langsung upload peserta
      if (_csvFilePath != null) {
        try {
          await _repo.addParticipantBulk(
            eventId: createdEvent.id,
            filePath: _csvFilePath!,
          );
          if (!mounted) return;
          _showSnackBar(
            'Event dibuat & peserta berhasil diimpor!',
            AppTheme.success,
          );
        } catch (bulkError) {
          if (!mounted) return;
          _showSnackBar(
            'Event dibuat, tapi gagal impor peserta: ${bulkError.toString().replaceFirst("Exception: ", "")}',
            AppTheme.warning,
          );
        }
      } else {
        if (!mounted) return;
        _showSnackBar(
          isDraft
              ? 'Event berhasil disimpan ke draft!'
              : 'Event berhasil dibuat!',
          isDraft ? AppTheme.textSecondary : AppTheme.success,
        );
      }
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        AppTheme.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _venueController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _csvFileName = null;
      _csvFilePath = null;
      _imageName = null;
      _imagePath = null;
      _latitude = null;
      _longitude = null;
      _locationAddress = null;
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageTitle(),
                      const SizedBox(height: 24),
                      _buildEventInfoCard(),
                      const SizedBox(height: 16),
                      _buildBulkUploadCard(),
                      const SizedBox(height: 32),
                      _buildPrimaryButton(),
                      const SizedBox(height: 12),
                      _buildDraftButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ───
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.menu_rounded,
              size: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const BrandText(fontSize: 28),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: 20,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Page title ───
  Widget _buildPageTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bikin Event Baru',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atur detail acaramu atau langsung gas upload daftar peserta biar makin sat-set!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Event Info Card ───
  Widget _buildEventInfoCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Informasi Event',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // EVENT NAME
          _buildFieldLabel('NAMA EVENT'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'contoh: Annual Tech Summit 2026',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Nama event jangan sampai kosong ya';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // EVENT IMAGE (Optional)
          _buildFieldLabel('GAMBAR EVENT (OPSIONAL)'),
          const SizedBox(height: 6),
          _buildImagePicker(),
          const SizedBox(height: 16),

          // DATE + TIME row
          Row(
            children: [
              // DATE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('TANGGAL'),
                    const SizedBox(height: 6),
                    _PickerTile(
                      text: _selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                          : 'mm/dd/yyyy',
                      icon: Icons.calendar_today_outlined,
                      hasValue: _selectedDate != null,
                      onTap: _pickDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // TIME
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('WAKTU'),
                    const SizedBox(height: 6),
                    _PickerTile(
                      text: _selectedTime != null
                          ? _selectedTime!.format(context)
                          : '--:-- --',
                      icon: Icons.access_time_rounded,
                      hasValue: _selectedTime != null,
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // CONTACT EMAIL
          _buildFieldLabel('EMAIL KONTAK (REPLY-TO)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'contoh: halo@hadir.in (Opsional)',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          // MAP PREVIEW
          _buildMapPreview(),
        ],
      ),
    );
  }

  // ─── Map Preview (Interactive) ───
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationAddress = result.address;
      });
    }
  }

  Widget _buildMapPreview() {
    final hasLocation = _latitude != null && _longitude != null;

    return GestureDetector(
      onTap: _openLocationPicker,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Map-like background
            Container(
              height: 160,
              width: double.infinity,
              color: const Color(0xFFB8CCAD),
              child: CustomPaint(painter: _MapGridPainter()),
            ),
            // Pick on map / Change location button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: hasLocation
                        ? const Color(0xFF10B981)
                        : AppTheme.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (hasLocation
                                    ? const Color(0xFF10B981)
                                    : AppTheme.primary)
                                .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasLocation
                            ? Icons.check_circle_rounded
                            : Icons.near_me_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasLocation ? 'Ubah Lokasi' : 'Pilih di peta',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Coordinates badge
            if (hasLocation)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_latitude!.toStringAsFixed(4)}°, ${_longitude!.toStringAsFixed(4)}°',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            // Address badge
            if (hasLocation && _locationAddress != null)
              Positioned(
                bottom: 8,
                right: 8,
                left: 100,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _locationAddress!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Import Daftar Peserta Card ───
  Widget _buildBulkUploadCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Masukin Daftar Peserta',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _onDownloadTemplate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Template',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Drop zone
          GestureDetector(
            onTap: _onPickCsv,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: _csvFileName != null
                    ? AppTheme.primary.withValues(alpha: 0.04)
                    : AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _csvFileName != null
                      ? AppTheme.primary.withValues(alpha: 0.4)
                      : AppTheme.textMuted.withValues(alpha: 0.3),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _csvFileName != null
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : AppTheme.card,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _csvFileName != null
                          ? Icons.check_circle_rounded
                          : Icons.cloud_upload_outlined,
                      size: 28,
                      color: _csvFileName != null
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _csvFileName ?? 'Klik buat pilih file CSV',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _csvFileName != null
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _csvFileName != null
                        ? 'Klik buat ganti file'
                        : 'Format: .csv — Maksimal 5.000 baris',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  // Remove button
                  if (_csvFileName != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _onRemoveCsv,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppTheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Batalin file',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Info note — disclaimer kolom
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'File CSV wajib punya kolom: '),
                        TextSpan(
                          text: 'name',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const TextSpan(text: ', '),
                        TextSpan(
                          text: 'email',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const TextSpan(text: ', dan '),
                        TextSpan(
                          text: 'noTelp',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' (opsional). Download template di atas biar gak ribet! 😉',
                        ),
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

  // ─── Primary gradient button ───
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _onPickImage,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.1),
            width: 1.5,
          ),
          image: _imagePath != null
              ? DecorationImage(
                  image: FileImage(io.File(_imagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _imagePath == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: AppTheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah Foto Event',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  if (_imageName != null)
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _imageName!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _onRemoveImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () => _onSubmit(),
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Buat Event',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ─── Save as draft button ───
  Widget _buildDraftButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: _isLoading ? null : () => _onSubmit(isDraft: true),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          'Simpan Draf',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ─── Reusable white card section ───
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Date/Time picker tile ───
class _PickerTile extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool hasValue;
  final VoidCallback onTap;

  const _PickerTile({
    required this.text,
    required this.icon,
    required this.onTap,
    this.hasValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: hasValue
              ? Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: hasValue ? AppTheme.textPrimary : AppTheme.textMuted,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            Icon(
              icon,
              size: 18,
              color: hasValue ? AppTheme.primary : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map-like grid pattern painter ───
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;

    final blockPaint = Paint()
      ..color = const Color(0xFF9DB89A)
      ..style = PaintingStyle.fill;

    // Draw irregular grid blocks
    final rects = [
      Rect.fromLTWH(0, 0, size.width * 0.45, size.height * 0.4),
      Rect.fromLTWH(size.width * 0.5, 0, size.width * 0.5, size.height * 0.35),
      Rect.fromLTWH(
        0,
        size.height * 0.45,
        size.width * 0.3,
        size.height * 0.55,
      ),
      Rect.fromLTWH(
        size.width * 0.35,
        size.height * 0.4,
        size.width * 0.65,
        size.height * 0.6,
      ),
    ];
    for (final r in rects) {
      canvas.drawRect(r, blockPaint);
    }

    // Horizontal roads
    for (final y in [size.height * 0.4, size.height * 0.7]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    // Vertical roads
    for (final x in [size.width * 0.47, size.width * 0.72]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

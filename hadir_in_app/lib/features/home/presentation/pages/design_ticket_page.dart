import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hadir_in_app/core/theme/app_theme.dart';
import 'package:hadir_in_app/features/event/data/repositories/event_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

class DesignTicketPage extends StatefulWidget {
  final String eventId;

  const DesignTicketPage({super.key, required this.eventId});

  @override
  State<DesignTicketPage> createState() => _DesignTicketPageState();
}

// Modes to toggle which element is being moved
enum _EditMode { qr, name }

class _DesignTicketPageState extends State<DesignTicketPage> {
  final EventRepository _repo = GetIt.I<EventRepository>();

  String? _imagePath; // Local path (when user picks new image)
  String? _serverTemplateUrl; // URL from server (existing saved template)
  bool _isLoading = false;
  bool _isFetchingTemplate = true;
  _EditMode _editMode = _EditMode.qr;

  // QR fractional positions (0.0 to 1.0)
  double _qrFractionX = 0.35;
  double _qrFractionY = 0.3;
  double _qrFractionSize = 0.25;

  // Name fractional positions
  double _nameFractionX = 0.05;
  double _nameFractionY = 0.7;
  double _nameFontSizeFraction = 0.05; // relative to image width
  String _nameColor = 'white';

  double _imageWidth = 1000;
  double _imageHeight = 600;

  @override
  void initState() {
    super.initState();
    _loadSavedTemplate();
  }

  Future<void> _loadSavedTemplate() async {
    try {
      final data = await _repo.getEventTemplate(widget.eventId);
      if (data != null && data['templateUrl'] != null) {
        final config = data['config'] as Map<String, dynamic>?;
        final img = await _loadNetworkImageDimensions(
          data['templateUrl'] as String,
        );
        if (!mounted) return;
        setState(() {
          _serverTemplateUrl = data['templateUrl'] as String;
          _imageWidth = img.width;
          _imageHeight = img.height;
          if (config != null) {
            _qrFractionX = _safe(config['qrX']) / _imageWidth;
            _qrFractionY = _safe(config['qrY']) / _imageHeight;
            _qrFractionSize = _safe(config['qrSize']) / _imageWidth;
            _nameFractionX = config['nameX'] != null
                ? _safe(config['nameX']) / _imageWidth
                : 0.05;
            _nameFractionY = config['nameY'] != null
                ? _safe(config['nameY']) / _imageHeight
                : 0.7;
            _nameFontSizeFraction = config['nameSize'] != null
                ? _safe(config['nameSize']) / _imageWidth
                : 0.05;
            _nameColor = config['nameColor'] as String? ?? 'white';
          }
        });
      }
    } catch (_) {
      // Template belum ada — tampilkan empty state
    } finally {
      if (mounted) setState(() => _isFetchingTemplate = false);
    }
  }

  double _safe(dynamic val) => (val as num?)?.toDouble() ?? 0.0;

  /// Download image from URL and decode to get width/height
  Future<({double width, double height})> _loadNetworkImageDimensions(
    String url,
  ) async {
    try {
      final resp = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(resp.data!);
      final decoded = await decodeImageFromList(bytes);
      return (
        width: decoded.width.toDouble(),
        height: decoded.height.toDouble(),
      );
    } catch (_) {
      return (width: 1000.0, height: 600.0);
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final bytes = await File(path).readAsBytes();
      final decoded = await decodeImageFromList(bytes);

      setState(() {
        _imagePath = path; // New local file selected
        _serverTemplateUrl = null; // Discard server preview
        _imageWidth = decoded.width.toDouble();
        _imageHeight = decoded.height.toDouble();
      });
    }
  }

  Future<void> _saveConfig() async {
    // Require local image if no server template exists yet
    if (_imagePath == null && _serverTemplateUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload template gambar terlebih dahulu!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Only upload a new image if user picked one; otherwise just update config
      if (_imagePath != null) {
        await _repo.uploadTemplate(widget.eventId, _imagePath!);
      }

      await _repo.updateTemplateConfig(
        eventId: widget.eventId,
        config: {
          'qrX': (_qrFractionX * _imageWidth).toInt(),
          'qrY': (_qrFractionY * _imageHeight).toInt(),
          'qrSize': (_qrFractionSize * _imageWidth).toInt(),
          'nameX': (_nameFractionX * _imageWidth).toInt(),
          'nameY': (_nameFractionY * _imageHeight).toInt(),
          'nameSize': (_nameFontSizeFraction * _imageWidth).toInt(),
          'nameColor': _nameColor,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template E-Ticket berhasil disimpan!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Design Studio',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_imagePath != null || _serverTemplateUrl != null)
            TextButton(
              onPressed: _isLoading ? null : _saveConfig,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Simpan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
            ),
        ],
      ),
      body: _isFetchingTemplate
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : (_imagePath == null && _serverTemplateUrl == null)
          ? _buildEmptyState()
          : _buildEditor(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.art_track_rounded,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Buat Tiket Unik Anda',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload desain kosong milik komunitas Anda (JPG/PNG). Aplikasi akan menyematkan QR Code dan Nama Peserta di atasnya.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: Text(
                'Upload Template',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        // Mode toggle toolbar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Geser QR',
                  icon: Icons.qr_code_2_rounded,
                  isActive: _editMode == _EditMode.qr,
                  onTap: () => setState(() => _editMode = _EditMode.qr),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Geser Nama',
                  icon: Icons.text_fields_rounded,
                  isActive: _editMode == _EditMode.name,
                  onTap: () => setState(() => _editMode = _EditMode.name),
                ),
              ),
            ],
          ),
        ),
        // Canvas
        Expanded(
          child: Center(
            child: InteractiveViewer(
              minScale: 0.3,
              maxScale: 4.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double imgRatio = _imageWidth / _imageHeight;
                  final double screenRatio =
                      constraints.maxWidth / constraints.maxHeight;

                  double rw, rh;
                  if (imgRatio > screenRatio) {
                    rw = constraints.maxWidth;
                    rh = rw / imgRatio;
                  } else {
                    rh = constraints.maxHeight;
                    rw = rh * imgRatio;
                  }

                  return Container(
                    width: rw,
                    height: rh,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Tampilkan gambar dari server ATAU file lokal
                        if (_imagePath != null)
                          Image.file(
                            File(_imagePath!),
                            width: rw,
                            height: rh,
                            fit: BoxFit.contain,
                          )
                        else if (_serverTemplateUrl != null)
                          Image.network(
                            _serverTemplateUrl!,
                            width: rw,
                            height: rh,
                            fit: BoxFit.contain,
                          ),

                        // QR Box
                        Positioned(
                          left: _qrFractionX * rw,
                          top: _qrFractionY * rh,
                          child: GestureDetector(
                            onPanUpdate: _editMode == _EditMode.qr
                                ? (d) => setState(() {
                                    _qrFractionX =
                                        (_qrFractionX + d.delta.dx / rw).clamp(
                                          0.0,
                                          1.0,
                                        );
                                    _qrFractionY =
                                        (_qrFractionY + d.delta.dy / rh).clamp(
                                          0.0,
                                          1.0,
                                        );
                                  })
                                : null,
                            child: Container(
                              width: _qrFractionSize * rw,
                              height: _qrFractionSize * rw,
                              decoration: BoxDecoration(
                                color: _editMode == _EditMode.qr
                                    ? Colors.black.withValues(alpha: 0.6)
                                    : Colors.black.withValues(alpha: 0.3),
                                border: Border.all(
                                  color: _editMode == _EditMode.qr
                                      ? Colors.white
                                      : Colors.white54,
                                  width: _editMode == _EditMode.qr ? 2.5 : 1.5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Colors.white,
                                  size: _qrFractionSize * rw * 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Name Label Box
                        Positioned(
                          left: _nameFractionX * rw,
                          top: _nameFractionY * rh,
                          child: GestureDetector(
                            onPanUpdate: _editMode == _EditMode.name
                                ? (d) => setState(() {
                                    _nameFractionX =
                                        (_nameFractionX + d.delta.dx / rw)
                                            .clamp(0.0, 1.0);
                                    _nameFractionY =
                                        (_nameFractionY + d.delta.dy / rh)
                                            .clamp(0.0, 1.0);
                                  })
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _editMode == _EditMode.name
                                    ? AppTheme.primary.withValues(alpha: 0.5)
                                    : AppTheme.primary.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: _editMode == _EditMode.name
                                      ? Colors.white
                                      : Colors.white54,
                                  width: _editMode == _EditMode.name
                                      ? 2.5
                                      : 1.5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Nama Peserta',
                                style: TextStyle(
                                  color: _nameColor == 'black'
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: (_nameFontSizeFraction * rw).clamp(
                                    8.0,
                                    48.0,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Control Panel
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: _editMode == _EditMode.qr
                ? _buildQrControls()
                : _buildNameControls(),
          ),
        ),
      ],
    );
  }

  Widget _buildQrControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ukuran QR Code',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(_qrFractionSize * 100).toInt()}%',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _qrFractionSize,
          min: 0.05,
          max: 0.8,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _qrFractionSize = v),
        ),
        TextButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.change_circle_rounded, color: Colors.black54),
          label: const Text(
            'Ganti Template',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildNameControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ukuran Font',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(_nameFontSizeFraction * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _nameFontSizeFraction,
          min: 0.02,
          max: 0.15,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _nameFontSizeFraction = v),
        ),
        Row(
          children: [
            Text(
              'Warna Teks:',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            _ColorChip(
              label: 'Putih',
              color: Colors.white,
              isSelected: _nameColor == 'white',
              onTap: () => setState(() => _nameColor = 'white'),
            ),
            const SizedBox(width: 8),
            _ColorChip(
              label: 'Hitam',
              color: Colors.black,
              isSelected: _nameColor == 'black',
              onTap: () => setState(() => _nameColor = 'black'),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color == Colors.white ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

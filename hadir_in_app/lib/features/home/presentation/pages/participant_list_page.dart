import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../event/data/models/event_detail_models.dart';
import 'package:get_it/get_it.dart';
import '../../../event/data/repositories/event_repository.dart';

class ParticipantListPage extends StatefulWidget {
  final String eventId;
  final List<ParticipantModel>? initialParticipants;
  final bool isOrganizer;

  const ParticipantListPage({
    super.key,
    required this.eventId,
    this.initialParticipants,
    this.isOrganizer = true,
  });

  @override
  State<ParticipantListPage> createState() => _ParticipantListPageState();
}

class _ParticipantListPageState extends State<ParticipantListPage> {
  final _repo = GetIt.instance<EventRepository>();
  List<ParticipantModel> _participants = [];
  List<ParticipantModel> _filteredParticipants = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialParticipants != null &&
        widget.initialParticipants!.isNotEmpty) {
      _participants = widget.initialParticipants!;
      _filteredParticipants = List.from(_participants);
    } else {
      _loadParticipants();
    }
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    try {
      final participants = await _repo.getParticipants(widget.eventId);
      setState(() {
        _participants = participants;
        _filterParticipants(_searchQuery);
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e.toString().replaceFirst('Exception: ', ''),
          AppTheme.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterParticipants(String query) {
    _searchQuery = query;
    setState(() {
      if (query.isEmpty) {
        _filteredParticipants = List.from(_participants);
      } else {
        _filteredParticipants = _participants
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query.toLowerCase()) ||
                  p.email.toLowerCase().contains(query.toLowerCase()) ||
                  p.ticketId.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
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

  // ─── Hapus peserta ───
  Future<void> _deleteParticipant(ParticipantModel p) async {
    try {
      await _repo.deleteParticipant(p.id);
      setState(() {
        _participants.removeWhere((x) => x.id == p.id);
        _filterParticipants(_searchQuery);
      });
      if (!mounted) return;
      _showSnackBar('${p.name} berhasil dihapus dari daftar', AppTheme.success);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        AppTheme.error,
      );
    }
  }

  // ─── Kirim tiket ke 1 peserta ───
  Future<void> _sendTicket(ParticipantModel p) async {
    try {
      final msg = await _repo.sendTicketToParticipant(p.id);
      if (!mounted) return;
      _showSnackBar(msg, AppTheme.success);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        AppTheme.error,
      );
    }
  }

  // ─── Edit peserta (bottom sheet) ───
  void _showEditSheet(ParticipantModel p) {
    final nameCtrl = TextEditingController(text: p.name);
    final emailCtrl = TextEditingController(text: p.email);
    final noTelpCtrl = TextEditingController(text: p.noTelp ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit Data Peserta',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildEditField(
                'Nama Lengkap',
                nameCtrl,
                Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildEditField('Email', emailCtrl, Icons.email_outlined),
              const SizedBox(height: 12),
              _buildEditField(
                'No. Telepon (opsional)',
                noTelpCtrl,
                Icons.phone_outlined,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: AppTheme.textMuted.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await _repo.updateParticipant(
                            id: p.id,
                            name: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            noTelp: noTelpCtrl.text.trim(),
                          );
                          _loadParticipants();
                          if (!mounted) return;
                          _showSnackBar(
                            'Data peserta berhasil diperbarui',
                            AppTheme.success,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          _showSnackBar(
                            e.toString().replaceFirst('Exception: ', ''),
                            AppTheme.error,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Simpan',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController ctrl,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: AppTheme.textMuted,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daftar Peserta',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: TextField(
              onChanged: _filterParticipants,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cari peserta...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textMuted,
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _filteredParticipants.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _loadParticipants,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                itemCount: _filteredParticipants.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = _filteredParticipants[index];
                  return _buildParticipantItem(p);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Peserta',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coba tambahkan peserta terlebih dahulu.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantItem(ParticipantModel p) {
    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Kirim tiket
          if (widget.isOrganizer)
            IconButton(
              onPressed: () => _confirmSendTicket(p),
              icon: const Icon(Icons.send_rounded),
              color: AppTheme.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Kirim Tiket',
              iconSize: 18,
            ),
          const SizedBox(width: 8),
          // QR Code
          IconButton(
            onPressed: () => _showQrDialog(context, p),
            icon: const Icon(Icons.qr_code_2_rounded),
            color: AppTheme.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Lihat QR',
            iconSize: 20,
          ),
          const SizedBox(width: 8),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: p.hasCheckedIn
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFF6B7280).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p.hasCheckedIn ? 'Hadir' : 'Absen',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: p.hasCheckedIn
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );

    // Swipe-to-delete + tap-to-edit (hanya organizer)
    if (!widget.isOrganizer) return card;

    return Dismissible(
      key: Key(p.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(p),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
      ),
      child: GestureDetector(onTap: () => _showEditSheet(p), child: card),
    );
  }

  Future<bool> _confirmDelete(ParticipantModel p) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Peserta',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Yakin ingin menghapus ${p.name} dari daftar peserta? Aksi ini tidak bisa dibatalkan.',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteParticipant(p);
      return true;
    }
    return false;
  }

  void _confirmSendTicket(ParticipantModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Kirim Tiket',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Kirim e-ticket ke ${p.name} di alamat ${p.email}?',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendTicket(p);
            },
            child: Text(
              'Kirim',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, ParticipantModel p) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tiket Peserta',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                p.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: QrImageView(
                  data: p.ticketId,
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tunjukkan QR code ini ke panitia saat check-in.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
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

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:io' as io;
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'package:hadir_in_app/features/home/presentation/pages/design_ticket_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/socket_service.dart';
import '../../../event/data/models/event_model.dart';
import '../../../event/data/models/event_detail_models.dart';
import '../../../event/data/repositories/event_repository.dart';
import 'add_participant_manual_page.dart';
import 'participant_list_page.dart';
import 'qr_scanner_page.dart';
import 'location_picker_page.dart';
import 'attendance_logs_page.dart';
import '../../../../core/constants/api_config.dart';

// import '../widgets/log_detail_sheet.dart';
import '../widgets/participant_range_picker_sheet.dart';
import '../widgets/control_button.dart';
import '../widgets/stat_card.dart';
import '../widgets/log_card.dart';
import '../../../../core/widgets/brand_text.dart';

class EventDetailPage extends StatefulWidget {
  final EventModel event;
  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}


class _EventDetailPageState extends State<EventDetailPage> {
  final _repo = GetIt.instance<EventRepository>();
  final _socketService = GetIt.instance<SocketService>();

  // Cached data — null berarti belum pernah load
  List<ParticipantModel>? _participants;
  List<AttendanceLogModel>? _logs;
  bool _isLoading = true;
  String? _error;

  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _isLive = widget.event.status == EventStatus.active;
    _refresh();

    // ─── Socket.IO: Join event room & listen for updates ───
    _socketService.joinEvent(widget.event.id);
    _socketService.onAttendanceUpdated((eventId) {
      if (eventId == widget.event.id && mounted) {
        debugPrint('🔄 [EventDetail] Real-time update received, refreshing...');
        _refresh(); // Silent refresh — no loading spinner
      }
    });
  }

  @override
  void dispose() {
    // ─── Socket.IO: Leave event room & cleanup listener ───
    _socketService.leaveEvent(widget.event.id);
    _socketService.offAttendanceUpdated();
    super.dispose();
  }

  Future<void> _refresh() async {
    // Hanya tampilkan loading jika belum pernah ada data (first load)
    if (_participants == null) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        _repo.getParticipants(widget.event.id),
        _repo.getAttendanceLogs(widget.event.id),
      ]);

      if (mounted) {
        setState(() {
          _participants = results[0] as List<ParticipantModel>;
          _logs = results[1] as List<AttendanceLogModel>;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // very light blue/grey bg
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : _error != null && _participants == null
                      ? Center(child: Text('Error: $_error'))
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final participants = _participants!;
    final logs = _logs!;

    final total = participants.length;
    final attended = participants
        .where((p) => p.hasCheckedIn)
        .length;
    final absent = total - attended;

    final absentPct = total > 0
        ? ((absent / total) * 100).toStringAsFixed(1)
        : '0';

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.event.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  widget.event.imageUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildHeaderTitle(),
            const SizedBox(height: 16),
            _buildLocationInfoCard(),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParticipantListPage(
                      eventId: widget.event.id,
                      initialParticipants: participants,
                    ),
                  ),
                );
              },
              child: _buildTotalCard(total),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Hadir',
                    value: attended.toString(),
                    subtext: '+0 from last min',
                    subtextColor: const Color(0xFF10B981),
                    dotColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Belum Datang',
                    value: absent.toString(),
                    subtext: '$absentPct% of total',
                    subtextColor: const Color(0xFF6B7280),
                    dotColor: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildEventControlSection(participants),
            const SizedBox(height: 32),
            _buildLogsSection(logs),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ───
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 24,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          const BrandText(fontSize: 20),
          const Spacer(),
          // Share Invite Button (Only for Organizer)
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              String? currentUserId;
              if (state is AuthAuthenticated) {
                currentUserId = state.userId;
              } else if (state is AuthLoginSuccess) {
                currentUserId = state.user.id;
              }
              if (currentUserId == widget.event.organizerId) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final inviteUrl =
                            '${ApiConfig.baseUrl}/invite/${widget.event.inviteCode}';
                        Share.share(
                          'Halo! Yuk bergabung menjadi panitia di event "${widget.event.name}" via Hadir.in.\n\nKlik link ini untuk bergabung: $inviteUrl',
                          subject: 'Undangan Panitia Hadir.in',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 20,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: AppTheme.primary,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') _showEditEventSheet();
                        if (value == 'delete') _confirmDeleteEvent();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Event',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppTheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hapus Event',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'REAL-TIME MONITOR',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            if (widget.event.date.isAtSameMomentAs(
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ),
            ))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.event.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfoCard() {
    final hasLocation =
        widget.event.latitude != null && widget.event.longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasLocation
                  ? const Color(0xFFEEF2FF)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasLocation
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: hasLocation ? AppTheme.primary : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation ? 'Lokasi Geofencing' : 'Lokasi tidak diatur',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLocation
                      ? '${widget.event.latitude!.toStringAsFixed(6)}, ${widget.event.longitude!.toStringAsFixed(6)}'
                      : 'Absensi mandiri tidak dibatasi jarak.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (hasLocation)
            GestureDetector(
              onTap: () async {
                final lat = widget.event.latitude;
                final lng = widget.event.longitude;

                // Coba buka Google Maps app langsung
                final googleMapsUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
                // Fallback ke browser
                final browserUrl = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                );

                try {
                  if (await canLaunchUrl(googleMapsUrl)) {
                    await launchUrl(
                      googleMapsUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    await launchUrl(
                      browserUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                } catch (e) {
                  debugPrint('Could not launch maps: $e');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lihat Peta',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary, // Solid blue
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Peserta',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                NumberFormat('#,###').format(total).replaceAll(',', '.'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          // Background icon watermark
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.people_alt_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection(List<AttendanceLogModel> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat Hadir',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            if (_isLive)
              Row(
                children: [
                  const Icon(
                    Icons.sensors_rounded,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (logs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Belum ada yang absen nih',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ),
          )
        else ...[
          // Ambil max 4 log teratas untuk preview
          ...logs.take(4).map((log) => LogCard(log: log)),
          const SizedBox(height: 12),
          // View Full Logs button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceLogsPage(
                    eventName: widget.event.name,
                    logs: logs,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF), // Soft blue bg
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Lihat Semua',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEventControlSection(List<ParticipantModel> participants) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String? currentUserId;
        if (state is AuthAuthenticated) {
          currentUserId = state.userId;
        } else if (state is AuthLoginSuccess) {
          currentUserId = state.user.id;
        }
        final isOwner = currentUserId == widget.event.organizerId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Control',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (isOwner) ...[
                  Expanded(
                    child: ControlButton(
                      icon: Icons.person_add_rounded,
                      label: 'Tambah Peserta',
                      onTap: () => _showAddParticipantOptions(),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: ControlButton(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan QR',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QRScannerPage(eventId: widget.event.id),
                        ),
                      );
                      _refresh(); // Immediately refresh stats upon returning from scan!
                    },
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
            if (isOwner) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ControlButton(
                      icon: Icons.design_services_rounded,
                      label: 'Desain E-Ticket',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DesignTicketPage(eventId: widget.event.id),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ControlButton(
                      icon: Icons.mark_email_read_rounded,
                      label: 'Kirim E-Tickets',
                      onTap: () => _showBlastDialog(participants),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ControlButton(
                icon: Icons.qr_code_2_rounded,
                label: 'Tampilkan QR Self Check-in',
                isFullWidth: true,
                onTap: () => _showSelfCheckinQR(context),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showBlastDialog(List<ParticipantModel> participants) async {
    bool isPartial = false;
    int? startValue;
    int? endValue;

    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada peserta untuk dikirimi tiket.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Default to the full range if not selected
    startValue = 1;
    endValue = participants.length;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
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
                      'Kirim E-Tickets',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kirim E-Ticket ke email peserta. Pilih rentang nama untuk membatasi pengiriman.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.textMuted.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            value: false,
                            groupValue: isPartial,
                            activeColor: AppTheme.primary,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              'Seluruh Peserta (${participants.length} Orang)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              'Kirim ke semua orang di daftar.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            onChanged: (v) => setState(() => isPartial = v!),
                          ),
                          Divider(
                            height: 1,
                            color: AppTheme.textMuted.withValues(alpha: 0.2),
                          ),
                          RadioListTile<bool>(
                            value: true,
                            groupValue: isPartial,
                            activeColor: AppTheme.primary,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              'Rentang Tertentu',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              'Berguna jika kuota email terbatas.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            onChanged: (v) => setState(() => isPartial = v!),
                          ),
                        ],
                      ),
                    ),
                    if (isPartial) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final res =
                                    await showModalBottomSheet<
                                      Map<String, int>
                                    >(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) =>
                                          ParticipantRangePickerSheet(
                                            participants: participants,
                                            initialStart: startValue,
                                            initialEnd: endValue,
                                          ),
                                    );
                                if (res != null) {
                                  setState(() {
                                    startValue = res['start'];
                                    endValue = res['end'];
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.touch_app_rounded,
                                size: 18,
                              ),
                              label: Text(
                                'Buka Daftar Peserta & Pilih',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(color: AppTheme.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                startValue != null && endValue != null
                                    ? 'Rentang terpilih: Urutan $startValue s/d $endValue. Total ${endValue! - startValue! + 1} Peserta.'
                                    : 'Silakan pilih rentang terlebih dahulu.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: AppTheme.textMuted.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: () {
                              if (isPartial) {
                                if (startValue == null ||
                                    endValue == null ||
                                    startValue! > endValue!) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Rentang tidak valid. Pastikan urutan akhir lebih besar/sama dengan urutan awal.',
                                        style: GoogleFonts.plusJakartaSans(),
                                      ),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(ctx, {
                                  'isPartial': true,
                                  'start': startValue,
                                  'end': endValue,
                                });
                              } else {
                                Navigator.pop(ctx, {'isPartial': false});
                              }
                            },
                            child: Text(
                              'Mulai Kirim E-Ticket',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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
          },
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;

    final targetCount = result['isPartial'] == true
        ? ((result['end'] as int) - (result['start'] as int) + 1)
        : participants.length;

    final agreed = await _showBlastWarning(targetCount);
    if (agreed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );

    try {
      if (result['isPartial'] == true) {
        await _repo.blastTickets(
          widget.event.id,
          startIndex: result['start'],
          endIndex: result['end'],
        );
      } else {
        await _repo.blastTickets(widget.event.id);
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Proses pengiriman tiket sedang berjalan di latar belakang!',
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showSelfCheckinQR(BuildContext context) {
    bool requirePhoto = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // URL web app for participant check-in
          final checkInUrl =
              '${ApiConfig.baseUrl}/attend/${widget.event.id}${requirePhoto ? "?requirePhoto=true" : ""}';

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Self Check-in QR',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Letakkan QR ini di meja masuk agar peserta dapat memindai dan mengisi absensi secara mandiri.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggle Require Photo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.camera_alt_rounded,
                          size: 20,
                          color: Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Wajibkan Foto Wajah',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ),
                        Switch(
                          value: requirePhoto,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) {
                            setDialogState(() {
                              requirePhoto = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: checkInUrl,
                      version: QrVersions.auto,
                      size: 220.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF111827),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddParticipantOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambah Peserta',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih cara menambahkan peserta untuk event ini.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              _buildAddOption(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Tambah Manual',
                subtitle: 'Masukkan data peserta satu per satu',
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddParticipantManualPage(eventId: widget.event.id),
                    ),
                  );
                  if (result == true) {
                    _refresh();
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildAddOption(
                icon: Icons.upload_file_rounded,
                title: 'Import dari CSV',
                subtitle: 'Upload file CSV berisi daftar peserta',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleBulkUpload();
                },
              ),
              const SizedBox(height: 16),
              _buildAddOption(
                icon: Icons.download_rounded,
                title: 'Download Template CSV',
                subtitle: 'Contoh format file yang bisa langsung diisi',
                onTap: () {
                  Navigator.pop(ctx);
                  _onDownloadTemplate();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBulkUpload() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );

        await _repo.addParticipantBulk(
          eventId: widget.event.id,
          filePath: result.files.single.path!,
        );

        if (!mounted) return;
        Navigator.pop(context); // Pop loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Peserta berhasil diimpor dari CSV!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog if any
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _onDownloadTemplate() async {
    final uri = Uri.parse('${ApiConfig.apiUrl}/participants/template/csv');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka browser'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // ─── Edit Event Sheet ───
  void _showEditEventSheet() {
    final nameCtrl = TextEditingController(text: widget.event.name);
    final descCtrl = TextEditingController(text: widget.event.description);
    final emailCtrl = TextEditingController(text: widget.event.contactEmail);

    double? tempLat = widget.event.latitude;
    double? tempLng = widget.event.longitude;
    String? tempAddress;
    String? tempImagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
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
                  'Edit Event',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildEditField('Nama Event', nameCtrl, Icons.event_rounded),
                const SizedBox(height: 12),
                _buildEditField(
                  'Deskripsi (opsional)',
                  descCtrl,
                  Icons.description_rounded,
                ),
                const SizedBox(height: 12),
                _buildEditField(
                  'Email Kontak (opsional)',
                  emailCtrl,
                  Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                // Location Picker
                Text(
                  'Lokasi Geofencing',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<LocationResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationPickerPage(
                          initialLatitude: tempLat,
                          initialLongitude: tempLng,
                        ),
                      ),
                    );
                    if (result != null) {
                      setSheetState(() {
                        tempLat = result.latitude;
                        tempLng = result.longitude;
                        tempAddress = result.address;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tempLat != null
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tempLat != null
                              ? Icons.location_on_rounded
                              : Icons.add_location_alt_rounded,
                          color: tempLat != null
                              ? const Color(0xFF10B981)
                              : AppTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tempLat != null
                                ? (tempAddress ??
                                      '${tempLat!.toStringAsFixed(6)}, ${tempLng!.toStringAsFixed(6)}')
                                : 'Set lokasi untuk geofencing',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: tempLat != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                              fontWeight: tempLat != null
                                  ? FontWeight.w600
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Image Picker
                Text(
                  'Gambar Event (Opsional)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.image,
                    );
                    if (result != null && result.files.single.path != null) {
                      setSheetState(() {
                        tempImagePath = result.files.single.path;
                      });
                    }
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      image: tempImagePath != null
                          ? DecorationImage(
                              image: FileImage(io.File(tempImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : widget.event.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.event.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        (tempImagePath == null && widget.event.imageUrl == null)
                        ? Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: AppTheme.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tambah Foto',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 32),
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
                            // Update text data
                            await _repo.updateEvent(
                              eventId: widget.event.id,
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              contactEmail: emailCtrl.text.trim(),
                              latitude: tempLat,
                              longitude: tempLng,
                            );

                            // Upload image if changed
                            if (tempImagePath != null) {
                              await _repo.uploadEventImage(
                                widget.event.id,
                                tempImagePath!,
                              );
                            }

                            if (!context.mounted) return;
                            _refresh();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Event berhasil diperbarui'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.error,
                              ),
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

  // ─── Hapus Event ───
  void _confirmDeleteEvent() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Event',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Yakin ingin menghapus event "${widget.event.name}"? Semua data peserta dan log kehadiran juga akan terhapus. Aksi ini tidak bisa dibatalkan.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repo.deleteEvent(widget.event.id);
                if (!mounted) return;
                Navigator.pop(context, true); // Pop back to home with result
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Event berhasil dihapus',
                      style: GoogleFonts.plusJakartaSans(),
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
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
  }

  Widget _buildAddOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  // --- DIALOG FOR T&C BLAST ---
  Future<bool?> _showBlastWarning(int targetCount) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.campaign_rounded,
              size: 48,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Kirim $targetCount Tiket?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pastikan data peserta sudah benar. Email tidak valid akan menghanguskan kredit tanpa refund.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(shape: StadiumBorder()),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: StadiumBorder(),
                    ),
                    child: const Text('Kirim', textAlign: TextAlign.center),
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

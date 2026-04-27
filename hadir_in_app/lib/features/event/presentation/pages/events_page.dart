import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_text.dart';
import '../../../../core/services/socket_service.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/event_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/event_card.dart';
import '../../../../core/widgets/status_chip.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _repo = GetIt.instance<EventRepository>();
  final _socketService = GetIt.instance<SocketService>();

  // Cached data — null berarti belum pernah load
  List<EventModel>? _events;
  bool _isLoading = true;
  String? _error;

  EventStatus? _selectedFilter; // null = semua

  @override
  void initState() {
    super.initState();
    _loadEvents();

    // ─── Socket.IO: Join user room & listen for event list updates ───
    _joinUserRoom();
    _socketService.onEventListUpdated(() {
      if (mounted) {
        debugPrint('🔄 [EventsPage] Event list updated via socket, refreshing...');
        _loadEvents();
      }
    });
  }

  @override
  void dispose() {
    _socketService.offEventListUpdated();
    super.dispose();
  }

  /// Join user room berdasarkan userId dari AuthBloc.
  void _joinUserRoom() {
    final authState = context.read<AuthBloc>().state;
    String? userId;
    if (authState is AuthAuthenticated) {
      userId = authState.userId;
    } else if (authState is AuthLoginSuccess) {
      userId = authState.user.id;
    }
    if (userId != null) {
      _socketService.joinUserRoom(userId);
    }
  }

  Future<void> _loadEvents() async {
    // Hanya tampilkan loading shimmer jika belum pernah ada data (first load)
    if (_events == null) {
      setState(() => _isLoading = true);
    }

    try {
      final events = await _repo.getMyEvents();
      if (mounted) {
        setState(() {
          _events = events;
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

  List<EventModel> _applyFilter(List<EventModel> events) {
    if (_selectedFilter == null) return events;
    return events.where((e) => e.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _error != null && _events == null
                      ? _buildError(_error!)
                      : _buildContent(_events!, _applyFilter(_events!)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Row(
        children: [
          // ─── Logo badge ───
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const BrandText(fontSize: 18),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildContent(List<EventModel> all, List<EventModel> filtered) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadEvents,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildSectionHeader(all)),
          SliverToBoxAdapter(child: _buildFilterChips()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)), // ← margin
          if (filtered.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: EventCard(event: filtered[i]),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(List<EventModel> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Semua Event',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${all.length} event ditemukan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 0, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            StatusChip(
              label: 'Semua',
              isSelected: _selectedFilter == null,
              onTap: () => setState(() => _selectedFilter = null),
            ),
            const SizedBox(width: 8),
            StatusChip(
              label: 'Live',
              isSelected: _selectedFilter == EventStatus.active,
              onTap: () => setState(() => _selectedFilter = EventStatus.active),
            ),
            const SizedBox(width: 8),
            StatusChip(
              label: 'Upcoming',
              isSelected: _selectedFilter == EventStatus.upcoming,
              onTap: () =>
                  setState(() => _selectedFilter = EventStatus.upcoming),
            ),
            const SizedBox(width: 8),
            StatusChip(
              label: 'Selesai',
              isSelected: _selectedFilter == EventStatus.ended,
              onTap: () => setState(() => _selectedFilter = EventStatus.ended),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
      itemCount: 3,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: EventShimmerCard(),
      ),
    );
  }

  Widget _buildError(String error) {
    final clean = error.replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat event',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              clean,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loadEvents,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Coba lagi',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🗓', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Belum ada event nih',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Yuk bikin event pertamamu!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

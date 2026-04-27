import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/event_detail_models.dart';
import '../../data/repositories/event_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/log_card.dart';

class AttendanceLogsPage extends StatefulWidget {
  final String eventName;
  final List<AttendanceLogModel> logs;

  const AttendanceLogsPage({
    super.key,
    required this.eventName,
    required this.logs,
  });

  @override
  State<AttendanceLogsPage> createState() => _AttendanceLogsPageState();
}

class _AttendanceLogsPageState extends State<AttendanceLogsPage> {
  late List<AttendanceLogModel> _logs;
  final EventRepository _repo = EventRepository();

  @override
  void initState() {
    super.initState();
    // Copy the logs so we can modify the list locally
    _logs = List.from(widget.logs);
  }

  void _deleteLog(int index) async {
    final logToDelete = _logs[index];

    // Optimistic UI update
    setState(() {
      _logs.removeAt(index);
    });

    try {
      await _repo.deleteAttendanceLog(logToDelete.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log berhasil dihapus.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Revert if failed
      setState(() {
        _logs.insert(index, logToDelete);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111827),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Hadir',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            Text(
              widget.eventName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
      body: _logs.isEmpty
          ? Center(
              child: Text(
                'Belum ada yang absen nih',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Dismissible(
                  key: Key(log.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  onDismissed: (direction) {
                    _deleteLog(index);
                  },
                  child: LogCard(log: log),
                );
              },
            ),
    );
  }
}

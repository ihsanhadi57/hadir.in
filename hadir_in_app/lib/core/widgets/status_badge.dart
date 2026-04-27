import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../../features/event/data/models/event_model.dart';

class StatusBadge extends StatelessWidget {
  final EventStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      EventStatus.active => (AppTheme.primary, AppTheme.surfaceContainerLow),
      EventStatus.upcoming => (
        AppTheme.textSecondary,
        AppTheme.surfaceContainerHigh,
      ),
      EventStatus.ended => (AppTheme.textMuted, AppTheme.surfaceContainerLow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == EventStatus.active) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            status.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

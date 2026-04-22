import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../event/data/models/event_detail_models.dart';

class ParticipantRangePickerSheet extends StatefulWidget {
  final List<ParticipantModel> participants;
  final int? initialStart;
  final int? initialEnd;

  const ParticipantRangePickerSheet({
    super.key,
    required this.participants,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<ParticipantRangePickerSheet> createState() => _ParticipantRangePickerSheetState();
}

class _ParticipantRangePickerSheetState extends State<ParticipantRangePickerSheet> {
  int? startIndex;
  int? endIndex;

  @override
  void initState() {
    super.initState();
    startIndex = widget.initialStart != null ? widget.initialStart! - 1 : null;
    endIndex = widget.initialEnd != null ? widget.initialEnd! - 1 : null;
  }

  void _handleTap(int index) {
    setState(() {
      if (startIndex == null) {
        startIndex = index;
        endIndex = index;
      } else if (startIndex != null && endIndex == startIndex) {
        if (index < startIndex!) {
          endIndex = startIndex;
          startIndex = index;
        } else {
          endIndex = index;
        }
      } else {
        // Reset to new tap
        startIndex = index;
        endIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Rentang',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (startIndex != null && endIndex != null) {
                      Navigator.pop(context, {'start': startIndex! + 1, 'end': endIndex! + 1});
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    'Selesai',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              'Tekan orang pertama, lalu tekan orang terakhir untuk membuat rentang biru selagi berurutan.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                final p = widget.participants[index];
                bool isSelected = false;
                bool isStart = false;
                bool isEnd = false;

                if (startIndex != null && endIndex != null) {
                  isSelected = index >= startIndex! && index <= endIndex!;
                  isStart = index == startIndex;
                  isEnd = index == endIndex;
                }

                return GestureDetector(
                  onTap: () => _handleTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.vertical(
                        top: isStart ? const Radius.circular(16) : Radius.zero,
                        bottom: isEnd ? const Radius.circular(16) : Radius.zero,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: (isEnd || (!isSelected && index != widget.participants.length - 1))
                                ? AppTheme.surfaceContainerLow
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.email,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.7) : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isStart || isEnd) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

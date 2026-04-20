import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/api_config.dart';
import '../../../event/data/models/event_detail_models.dart';

class LogDetailSheet extends StatelessWidget {
  final AttendanceLogModel log;

  const LogDetailSheet({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    // Memastikan path foto tidak double slash
    String? cleanPhotoUrl;
    if (log.photoUrl != null && log.photoUrl!.isNotEmpty) {
      String cleanPath = log.photoUrl!.startsWith('/')
          ? log.photoUrl!.substring(1)
          : log.photoUrl!;
      cleanPhotoUrl = '${ApiConfig.baseUrl}/$cleanPath';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Detail Absen',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),

          // Photo (if available)
          if (cleanPhotoUrl != null)
            Container(
              width: double.infinity,
              height: 300,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(cleanPhotoUrl),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.no_photography_rounded,
                    size: 48,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gak ada foto absen',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          _buildDetailRow(
            Icons.person_rounded,
            'Nama',
            log.participantName ?? 'Gak diketahui',
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.access_time_filled_rounded,
            'Waktu',
            log.scannedAt.toString().split('.')[0],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.location_on_rounded,
            'Lokasi',
            log.latitude != null
                ? '${log.latitude}, ${log.longitude}'
                : 'Lokasi gak kerekam',
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Tutup',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

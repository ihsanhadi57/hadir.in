import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class HelpFaqPage extends StatefulWidget {
  const HelpFaqPage({super.key});

  @override
  State<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends State<HelpFaqPage> {
  final List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'Gimana cara bikin event baru?',
      answer:
          'Gampang banget! Buka tab "Event" di bagian bawah, terus klik tombol + di kanan bawah. Isi nama event, tanggal, dan lokasi. Kamu juga bisa langsung upload daftar peserta via file CSV di halaman yang sama. Sat-set!',
      icon: Icons.add_circle_outline_rounded,
      color: Color(0xFF6C63FF),
    ),
    _FaqItem(
      question: 'Gimana cara blast e-ticket ke semua peserta?',
      answer:
          'Masuk ke halaman detail event-mu, terus cari tombol "Blast E-Ticket". Sistem bakal otomatis generate QR Code unik untuk tiap peserta dan kirim ke email mereka. Prosesnya jalan di background, jadi kamu bisa lanjut ngerjain hal lain!',
      icon: Icons.email_outlined,
      color: Color(0xFF10B981),
    ),
    _FaqItem(
      question: 'Apa itu quota email dan cara kerjanya?',
      answer:
          'Quota email adalah jatah berapa email yang bisa kamu kirim. Setiap akun baru dapat 50 email gratis. Satu kali blast ke 10 peserta = 10 quota terpakai. Kalau habis, kamu bisa top-up dengan harga yang super terjangkau!',
      icon: Icons.data_usage_rounded,
      color: Color(0xFFF59E0B),
    ),
    _FaqItem(
      question: 'Gimana cara nambah quota email?',
      answer:
          'Tinggal klik "Tambah Quota" di halaman Akun ini. Kamu bisa pilih paket yang sesuai kebutuhan event-mu. Pembayaran via Midtrans — support semua metode dari transfer bank, QRIS, sampai e-wallet. Langsung aktif setelah bayar!',
      icon: Icons.add_card_rounded,
      color: Color(0xFF004AC6),
    ),
    _FaqItem(
      question: 'Bisa impor peserta dari Excel/CSV?',
      answer:
          'Bisa banget! Download template CSV-nya dulu dari halaman buat event. Isi kolom name, email, dan noTelp (opsional). Terus upload deh. Sistem kita support file .csv, .xlsx, dan .xls. Peserta bakal langsung ter-register semua!',
      icon: Icons.upload_file_rounded,
      color: Color(0xFF06B6D4),
    ),
    _FaqItem(
      question: 'Apakah peserta bisa check-in sendiri?',
      answer:
          'Ya! Fitur Self-Check-In tersedia. Bagikan kode unik event ke peserta, mereka tinggal scan QR atau masukkan kode. Sistem akan validasi lokasinya (dalam radius 200 meter dari venue) sebelum absensi dikonfirmasi.',
      icon: Icons.qr_code_scanner_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _FaqItem(
      question: 'Gimana cara lihat data kehadiran?',
      answer:
          'Semua log kehadiran bisa kamu pantau real-time di halaman detail event bagian "Log Kehadiran". Ada foto selfie peserta juga kalau mode kamera aktif. Bisa difilter berdasarkan status hadir atau belum hadir.',
      icon: Icons.fact_check_outlined,
      color: Color(0xFFEC4899),
    ),
    _FaqItem(
      question: 'E-ticket tidak masuk ke email peserta. Kenapa?',
      answer:
          'Cek dulu apakah quota mencukupi dan email peserta sudah benar. Email kadang masuk ke folder Spam/Promosi, minta peserta cek di sana. Kalau masih bermasalah, kamu bisa kirim ulang tiket ke peserta tertentu dari halaman daftar peserta.',
      icon: Icons.help_outline_rounded,
      color: Color(0xFFF97316),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bantuan & FAQ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Banner ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hai! Ada yang bisa dibantu? 👋',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Temukan jawaban dari pertanyaan yang paling sering ditanyain di bawah ini.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── FAQ List ───
            Text(
              'Pertanyaan Umum',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_faqs.length, (i) => _FaqCard(item: _faqs[i])),

            // ─── Contact Card ───
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 32, color: AppTheme.primary),
                  const SizedBox(height: 10),
                  Text(
                    'Masih ada pertanyaan?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hubungi tim kami di support@hadir.in atau DM Instagram @hadir.in — kami balas dalam 1x24 jam kerja!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryContainer],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Hubungi Kami',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  final IconData icon;
  final Color color;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.icon,
    required this.color,
  });
}

class _FaqCard extends StatefulWidget {
  final _FaqItem item;
  const _FaqCard({required this.item});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.item.icon,
                          size: 18, color: widget.item.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.question,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _isExpanded
                      ? Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.item.answer,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../event/data/repositories/payment_repository.dart';

/// Status pembayaran yang diambil dari backend database.
enum _TxStatus { checking, settlement, pending, failure, unknown }

/// Halaman yang tampil setelah user kembali dari halaman pembayaran Midtrans.
///
/// [status] dari deep link bisa 'finish' atau 'error'.
/// PENTING: 'finish' bukan berarti berhasil — Midtrans mengarahkan ke 'finish'
/// untuk SEMUA kondisi (bayar, batal, pending).
/// Status sebenarnya diambil dari database backend via [PaymentRepository.getLatestTransaction].
class PaymentResultPage extends StatefulWidget {
  final String deepLinkStatus;

  const PaymentResultPage({super.key, required this.deepLinkStatus});

  @override
  State<PaymentResultPage> createState() => _PaymentResultPageState();
}

class _PaymentResultPageState extends State<PaymentResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  _TxStatus _txStatus = _TxStatus.checking;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    // Jika deep link sudah 'error', tidak perlu cek backend
    if (widget.deepLinkStatus == 'error') {
      _setStatus(_TxStatus.failure);
    } else {
      _checkActualStatus();
    }
  }

  /// Cek status pembayaran ASLI dari database backend.
  /// Midtrans 'finish' deep link tidak berarti sukses — perlu konfirmasi webhook.
  Future<void> _checkActualStatus() async {
    setState(() => _txStatus = _TxStatus.checking);

    // Tunggu 2 detik agar webhook Midtrans sempat diproses backend
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final paymentRepo = sl<PaymentRepository>();
    final tx = await paymentRepo.getLatestTransaction();

    if (!mounted) return;

    if (tx == null) {
      _setStatus(_TxStatus.unknown);
      return;
    }

    final String dbStatus = (tx['status'] as String?) ?? '';

    switch (dbStatus) {
      case 'settlement':
        // Berhasil bayar → refresh quota user
        context.read<AuthBloc>().add(FetchProfileRequested());
        _setStatus(_TxStatus.settlement);
        break;
      case 'pending':
        // Pembayaran diterima tapi belum dikonfirmasi (misal: transfer bank)
        _setStatus(_TxStatus.pending);
        break;
      case 'failure':
      case 'cancel':
      case 'deny':
      case 'expire':
        _setStatus(_TxStatus.failure);
        break;
      default:
        // Status belum diupdate (webhook belum diproses) — coba retry
        await _retryIfNeeded();
    }
  }

  /// Coba ulang pengecekan jika status masih belum final (max 3x, interval 3 detik).
  Future<void> _retryIfNeeded() async {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) await _checkActualStatus();
    } else {
      // Setelah max retry, anggap pending (mungkin webhook terlambat)
      _setStatus(_TxStatus.pending);
    }
  }

  void _setStatus(_TxStatus status) {
    if (!mounted) return;
    setState(() => _txStatus = status);
    if (status != _TxStatus.checking) {
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Cegah back button saat loading
      onPopInvokedWithResult: (didPop, result) {
        if (_txStatus != _TxStatus.checking) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: _txStatus == _TxStatus.checking
                ? _buildLoadingState()
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        _buildStatusIcon(),
                        const SizedBox(height: 32),
                        _buildTitle(),
                        const SizedBox(height: 12),
                        _buildSubtitle(),
                        const Spacer(),
                        if (_txStatus == _TxStatus.pending ||
                            _txStatus == _TxStatus.unknown)
                          _buildRefreshButton(),
                        const SizedBox(height: 12),
                        _buildHomeButton(context),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memeriksa status pembayaran...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: AppTheme.textMuted,
            ),
          ),
          if (_retryCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Mencoba ulang ($_retryCount/$_maxRetries)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    final Color bgColor;
    final Color iconColor;
    final IconData icon;

    switch (_txStatus) {
      case _TxStatus.settlement:
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
        iconColor = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        break;
      case _TxStatus.failure:
        bgColor = AppTheme.error.withValues(alpha: 0.1);
        iconColor = AppTheme.error;
        icon = Icons.cancel_rounded;
        break;
      case _TxStatus.pending:
      case _TxStatus.unknown:
      default:
        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.1);
        iconColor = const Color(0xFFF59E0B);
        icon = Icons.hourglass_top_rounded;
        break;
    }

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 64, color: iconColor),
      ),
    );
  }

  Widget _buildTitle() {
    final String title = switch (_txStatus) {
      _TxStatus.settlement => 'Pembayaran Berhasil! 🎉',
      _TxStatus.failure => 'Pembayaran Gagal',
      _TxStatus.pending => 'Menunggu Konfirmasi',
      _ => 'Status Belum Diketahui',
    };

    return Text(
      title,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildSubtitle() {
    final String subtitle = switch (_txStatus) {
      _TxStatus.settlement =>
        'Quota email kamu sudah ditambahkan!\nKamu bisa langsung menggunakannya untuk mengirim tiket event.',
      _TxStatus.failure =>
        'Pembayaran tidak berhasil atau dibatalkan.\nKamu bisa mencoba kembali kapan saja dari halaman Akun.',
      _TxStatus.pending =>
        'Pembayaran sedang menunggu konfirmasi.\nQuota akan ditambahkan otomatis setelah bank mengkonfirmasi pembayaran.',
      _ =>
        'Kami belum bisa memastikan status pembayaranmu.\nCoba refresh atau cek riwayat transaksi di halaman Akun.',
    };

    return Text(
      subtitle,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: AppTheme.textMuted,
        height: 1.6,
      ),
    );
  }

  Widget _buildRefreshButton() {
    return TextButton.icon(
      onPressed: () {
        _retryCount = 0;
        _checkActualStatus();
      },
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: Text(
        'Cek ulang status',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'Kembali ke Beranda',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

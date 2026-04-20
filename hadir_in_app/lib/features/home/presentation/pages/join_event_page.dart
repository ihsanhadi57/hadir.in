import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../event/data/repositories/event_repository.dart';
import 'home_page.dart';

class JoinEventPage extends StatefulWidget {
  final String inviteCode;
  const JoinEventPage({super.key, required this.inviteCode});

  @override
  State<JoinEventPage> createState() => _JoinEventPageState();
}

class _JoinEventPageState extends State<JoinEventPage> {
  final _repo = GetIt.instance<EventRepository>();
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start joining after a short delay to ensure app state is ready
    Future.delayed(const Duration(milliseconds: 500), _attemptJoin);
  }

  Future<void> _attemptJoin() async {
    final authState = context.read<AuthBloc>().state;
    
    if (authState is! AuthAuthenticated) {
      setState(() {
        _error = 'Silakan login terlebih dahulu untuk bergabung.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final message = await _repo.joinEvent(widget.inviteCode);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      // Successfully joined, go to Home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
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
                  Icons.group_add_rounded,
                  size: 64,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Grup Panitia',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sedang memproses undangan untuk kode: ${widget.inviteCode}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              if (_isProcessing)
                const CircularProgressIndicator(color: AppTheme.primary)
              else if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Ke Beranda', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

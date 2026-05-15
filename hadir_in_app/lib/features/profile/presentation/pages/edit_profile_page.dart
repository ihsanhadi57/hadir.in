import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel user;
  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _changePassword = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    if (_changePassword &&
        _newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Password baru dan konfirmasi tidak sama!', AppTheme.error);
      return;
    }

    context.read<AuthBloc>().add(
      UpdateProfileRequested(
        name: _nameController.text.trim(),
        currentPassword: _changePassword
            ? _currentPasswordController.text
            : null,
        newPassword: _changePassword ? _newPasswordController.text : null,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthProfileUpdateSuccess) {
          _showSnackBar('Profil berhasil diperbarui!', AppTheme.success);
          Navigator.pop(context);
        } else if (state is AuthFailure) {
          _showSnackBar(state.message, AppTheme.error);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Profil',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthProfileUpdating;
            return SingleChildScrollView(
              padding: EdgeInsets.all(
                ResponsiveLayout.contentPadding(context),
              ),
              child: ResponsiveCenter(
                maxWidth: 540,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // ─── Avatar (Photo or Initials) ───
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              image: widget.user.avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        widget.user.avatarUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: widget.user.avatarUrl == null
                                ? Center(
                                    child: Text(
                                      widget.user.name.isNotEmpty
                                          ? widget.user.name[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        widget.user.email,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Nama ───
                    _buildSectionCard(
                      title: 'Informasi Dasar',
                      icon: Icons.person_outline_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('NAMA LENGKAP'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Masukkan nama lengkap',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Nama tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Ganti Password Toggle ───
                    GestureDetector(
                      onTap: () =>
                          setState(() => _changePassword = !_changePassword),
                      child: _buildSectionCard(
                        title: 'Keamanan Akun',
                        icon: Icons.lock_outline_rounded,
                        trailing: Switch(
                          value: _changePassword,
                          onChanged: (v) => setState(() => _changePassword = v),
                          activeThumbColor: AppTheme.primary,
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _changePassword
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 16),
                                    _buildFieldLabel('PASSWORD LAMA'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _currentPasswordController,
                                      obscureText: !_showCurrentPassword,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Masukkan password lama',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showCurrentPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _showCurrentPassword =
                                                !_showCurrentPassword,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (_changePassword &&
                                            (v == null || v.isEmpty)) {
                                          return 'Password lama wajib diisi';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildFieldLabel('PASSWORD BARU'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _newPasswordController,
                                      obscureText: !_showNewPassword,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Minimal 8 karakter',
                                        prefixIcon: const Icon(
                                          Icons.key_outlined,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showNewPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _showNewPassword =
                                                !_showNewPassword,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (_changePassword) {
                                          if (v == null || v.isEmpty)
                                            return 'Password baru wajib diisi';
                                          if (v.length < 8)
                                            return 'Minimal 8 karakter';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildFieldLabel('KONFIRMASI PASSWORD'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: !_showConfirmPassword,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Ulangi password baru',
                                        prefixIcon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showConfirmPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _showConfirmPassword =
                                                !_showConfirmPassword,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (_changePassword &&
                                            (v == null || v.isEmpty)) {
                                          return 'Konfirmasi password wajib diisi';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                )
                              : Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Aktifkan untuk mengubah password akun',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Save Button ───
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isLoading ? null : _onSave,
                            borderRadius: BorderRadius.circular(999),
                            child: Center(
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Simpan Perubahan',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

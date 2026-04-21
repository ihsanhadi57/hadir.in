import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<FetchProfileRequested>(_onFetchProfileRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  // ─── Cek JWT saat app dibuka (Splash Screen) ───
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.checkAuthStatus();
    if (result.isLoggedIn && result.userId != null) {
      // Emit authenticated dulu, kemudian fetch profil lengkap
      emit(AuthAuthenticated(userId: result.userId!));
      try {
        final user = await authRepository.getMe();
        emit(AuthAuthenticated(userId: user.id, user: user));
      } catch (_) {
        // Jika gagal ambil profil, berarti token sudah tidak valid (misal: pindah DB)
        // Hapus token dan lempar ke Unauthenticated (Login)
        await authRepository.logout();
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  // ─── Fetch Profil Terbaru ───
  Future<void> _onFetchProfileRequested(
    FetchProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await authRepository.getMe();
      emit(AuthAuthenticated(userId: user.id, user: user));
    } catch (e) {
      // Abaikan error fetch profil, tidak logout user
    }
  }

  // ─── Login ───
  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(event.email, event.password);
      emit(AuthLoginSuccess(user: user));
    } on Exception catch (e) {
      emit(AuthFailure(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ─── Login with Google ───
  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.loginWithGoogle();
      emit(AuthLoginSuccess(user: user));
    } on Exception catch (e) {
      emit(AuthFailure(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ─── Register ───
  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.register(event.name, event.email, event.password);
      emit(const AuthRegisterSuccess());
    } on Exception catch (e) {
      emit(AuthFailure(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ─── Update Profil ───
  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthProfileUpdating());
    try {
      final updatedUser = await authRepository.updateProfile(
        name: event.name,
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      emit(AuthProfileUpdateSuccess(user: updatedUser));
      // Re-emit authenticated state dengan data terbaru
      emit(AuthAuthenticated(userId: updatedUser.id, user: updatedUser));
    } on Exception catch (e) {
      emit(AuthFailure(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ─── Verifikasi OTP ───
  Future<void> _onVerifyOtpRequested(
    VerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.verifyOtp(event.email, event.otp);
      emit(AuthOtpVerificationSuccess(user: user));
      // Re-emit authenticated state agar app langsung masuk ke home
      emit(AuthAuthenticated(userId: user.id, user: user));
    } on Exception catch (e) {
      emit(AuthFailure(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ─── Logout ───
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await authRepository.logout();
    emit(AuthLoggedOut());
  }
}

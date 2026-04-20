import 'package:equatable/equatable.dart';
import '../../data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

// State awal sebelum ada aksi apapun
class AuthInitial extends AuthState {}

// State saat proses sedang berjalan (loading)
class AuthLoading extends AuthState {}

// State saat Login berhasil (membawa user lengkap dari server)
class AuthLoginSuccess extends AuthState {
  final UserModel user;
  const AuthLoginSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}

// State saat sedang memproses update profil
class AuthProfileUpdating extends AuthState {}

// State saat update profil berhasil
class AuthProfileUpdateSuccess extends AuthState {
  final UserModel user;
  const AuthProfileUpdateSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}

// State saat Register berhasil
class AuthRegisterSuccess extends AuthState {
  final String message;

  const AuthRegisterSuccess({
    this.message = 'Registrasi berhasil! Silakan login.',
  });

  @override
  List<Object?> get props => [message];
}

// State saat terjadi error (login gagal / register gagal)
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// State saat logout berhasil
class AuthLoggedOut extends AuthState {}

// State saat app buka dan token ditemukan (sudah login) 
class AuthAuthenticated extends AuthState {
  final String userId;
  final UserModel? user; // Bisa null saat awal, diisi setelah getMe
  const AuthAuthenticated({required this.userId, this.user});

  @override
  List<Object?> get props => [userId, user];
}

// State saat app buka dan token tidak ada / invalid
class AuthUnauthenticated extends AuthState {}

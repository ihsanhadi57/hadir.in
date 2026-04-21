import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// Event saat user menekan tombol Login
class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

// Event saat user menekan tombol Login dengan Google
class GoogleLoginRequested extends AuthEvent {}

// Event saat user menekan tombol Register
class RegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;

  const RegisterRequested({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [name, email, password];
}

// Event saat user menekan tombol Logout
class LogoutRequested extends AuthEvent {}

// Event saat app pertama dibuka — cek apakah JWT masih ada
class AuthCheckRequested extends AuthEvent {}

// Event saat user menyimpan perubahan profil
class UpdateProfileRequested extends AuthEvent {
  final String? name;
  final String? currentPassword;
  final String? newPassword;

  const UpdateProfileRequested({
    this.name,
    this.currentPassword,
    this.newPassword,
  });

  @override
  List<Object?> get props => [name, currentPassword, newPassword];
}

// Event untuk refresh data profil dari server (setelah login via token)
class FetchProfileRequested extends AuthEvent {}

// Event untuk verifikasi OTP
class VerifyOtpRequested extends AuthEvent {
  final String email;
  final String otp;

  const VerifyOtpRequested({required this.email, required this.otp});

  @override
  List<Object?> get props => [email, otp];
}

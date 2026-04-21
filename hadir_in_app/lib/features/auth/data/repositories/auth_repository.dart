import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  AuthRepository({DioClient? dioClient, SecureStorageService? storageService})
      : _dioClient = dioClient ?? DioClient(),
        _storageService = storageService ?? SecureStorageService();

  String _getErrorMessage(DioException e, String defaultMsg) {
    if (e.response?.data is Map<String, dynamic>) {
      return e.response?.data['message'] as String? ?? defaultMsg;
    }
    return defaultMsg;
  }

  // ─── Cek status autentikasi saat app dibuka ───
  Future<({bool isLoggedIn, String? userId})> checkAuthStatus() async {
    final token = await _storageService.getToken();
    final userId = await _storageService.getUserId();
    return (isLoggedIn: token != null && token.isNotEmpty, userId: userId);
  }

  // ─── Login ───
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final responseData = response.data['data'] as Map<String, dynamic>;
      final token = responseData['token'] as String;
      final userJson = responseData['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      await _storageService.saveAuthData(token, user.id);
      return user;
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Terjadi kesalahan jaringan'));
    }
  }

  // ─── Register ───
  Future<void> register(String name, String email, String password) async {
    try {
      await _dioClient.dio.post(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal mendaftar'));
    }
  }

  // ─── Verify OTP ───
  Future<UserModel> verifyOtp(String email, String otp) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/verify-otp',
        data: {'email': email, 'otp': otp},
      );

      final responseData = response.data['data'] as Map<String, dynamic>;
      final token = responseData['token'] as String;
      final userJson = responseData['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      await _storageService.saveAuthData(token, user.id);
      return user;
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Verifikasi gagal. Pastikan kode benar.'));
    }
  }

  // ─── Login with Google ───
  Future<UserModel> loginWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '115014454509-rv7ssl50u52i440c9vs3p9t54ak84sdn.apps.googleusercontent.com',
      );

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Gagal mendapatkan token dari Google');
      }

      final response = await _dioClient.dio.post(
        '/auth/google',
        data: {'idToken': idToken},
      );

      final responseData = response.data as Map<String, dynamic>;
      final token = responseData['token'] as String;
      final userJson = responseData['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      await _storageService.saveAuthData(token, user.id);
      return user;
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Koneksi ke server gagal'));
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ─── Get Current User Profile ───
  Future<UserModel> getMe() async {
    try {
      final response = await _dioClient.dio.get('/auth/me');
      final userJson = response.data['data'] as Map<String, dynamic>;
      return UserModel.fromJson(userJson);
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal memuat profil'));
    }
  }

  // ─── Update Profile (nama & password) ───
  Future<UserModel> updateProfile({
    String? name,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final response = await _dioClient.dio.put(
        '/auth/profile',
        data: {
          if (name != null && name.isNotEmpty) 'name': name,
          if (currentPassword != null && currentPassword.isNotEmpty) 'currentPassword': currentPassword,
          if (newPassword != null && newPassword.isNotEmpty) 'newPassword': newPassword,
        },
      );
      final userJson = response.data['data'] as Map<String, dynamic>;
      return UserModel.fromJson(userJson);
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal memperbarui profil'));
    }
  }

  // ─── Logout ───
  Future<void> logout() async {
    await GoogleSignIn.instance.signOut();
    await _storageService.deleteAuthData();
  }
}

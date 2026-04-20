import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Kunci (Key) untuk menyimpan token
  static const String _tokenKey = 'jwt_token';

  // Menyimpan token dan user ID setelah login berhasil
  Future<void> saveAuthData(String token, String userId) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: 'user_id', value: userId);
  }

  // Mengambil token untuk disisipkan ke header
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Mengambil user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  // Menghapus data saat logout
  Future<void> deleteAuthData() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: 'user_id');
  }
}

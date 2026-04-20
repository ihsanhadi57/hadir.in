import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import '../constants/api_config.dart';

class DioClient {
  late Dio _dio;
  final SecureStorageService _storageService = SecureStorageService();

  /// Callback yang dipanggil saat server mengembalikan 401 (token expired)
  /// Diisi dari luar (mis. dari main.dart atau AuthBloc) untuk trigger logout
  void Function()? onUnauthorized;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        // Gunakan 10.0.2.2 untuk Android Emulator (loopback ke host machine)
        // Ganti dengan URL production saat deploy
        baseUrl: ApiConfig.apiUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        // ─── Sebelum request dikirim: sisipkan JWT ke header ───
        onRequest: (options, handler) async {
          final token = await _storageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        // ─── Saat error: tangani 401 (token expired/invalid) ───
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Hapus token yang expired dari storage
            await _storageService.deleteAuthData();
            // Trigger callback untuk navigasi ke Login (dipasang dari luar)
            onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}

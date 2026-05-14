import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class PaymentRepository {
  final DioClient _dioClient;

  PaymentRepository(this._dioClient);

  /// Create a Midtrans Snap transaction
  /// Returns a Map containing [token] and [redirect_url]
  Future<Map<String, dynamic>> createSnapTransaction({
    required int quota,
    required int amount,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/payment/create-snap',
        data: {
          'quota': quota,
          'amount': amount,
        },
      );

      // Backend returns structure: { status: 'success', data: { token, redirect_url, orderId } }
      if (response.data['status'] == 'success') {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal membuat transaksi');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan koneksi saat membuat pembayaran.';
      throw Exception(message);
    } catch (e) {
      throw Exception('Gagal membuat transaksi: $e');
    }
  }

  /// Ambil transaksi topup terbaru dari backend.
  /// Digunakan oleh PaymentResultPage untuk cek status pembayaran yang sebenarnya.
  /// Return null jika tidak ada transaksi atau gagal fetch.
  Future<Map<String, dynamic>?> getLatestTransaction() async {
    try {
      final response = await _dioClient.dio.get('/payment/history');
      if (response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] as List<dynamic>;
        if (data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
      }
      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

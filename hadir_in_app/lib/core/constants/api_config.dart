class ApiConfig {
  static const String baseUrl = 'https://hadirin.space';
  static const String apiUrl = '$baseUrl/api';

  // CATATAN: Socket.IO menggunakan URL Render.com langsung (bukan custom domain hadirin.space)
  // karena proxy custom domain kadang tidak support WebSocket upgrade dengan benar.
  // Ganti ke 'https://hadirin.space' HANYA jika server Nginx/Cloudflare sudah dikonfigurasi
  // untuk proxy WebSocket (header Upgrade + Connection).
  static const String socketUrl = 'https://hadir-in.onrender.com';
}

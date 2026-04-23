import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_config.dart';

/// Service untuk mengelola koneksi Socket.IO ke backend.
/// Menggunakan socket_io_client v3.x dengan OptionBuilder().
class SocketService {
  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Connect ke Socket.IO server di Render.com.
  /// PENTING: Gunakan URL Render langsung, bukan custom domain.
  void connect() {
    if (_socket != null && _socket!.connected) {
      debugPrint('🔌 [SocketService] Already connected, skipping.');
      return;
    }

    debugPrint('🔌 [SocketService] Connecting to ${ApiConfig.socketUrl}...');

    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling']) // WebSocket first, fallback to polling
          .disableAutoConnect() // Manual connect
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('✅ [SocketService] Connected! ID: ${_socket!.id}');
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ [SocketService] Connection error: $error');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('⚠️ [SocketService] Disconnected: $reason');
    });

    _socket!.onReconnect((_) {
      debugPrint('🔄 [SocketService] Reconnected!');
    });

    _socket!.onReconnectAttempt((attemptNumber) {
      debugPrint('🔄 [SocketService] Reconnection attempt #$attemptNumber');
    });

    _socket!.onReconnectError((error) {
      debugPrint('❌ [SocketService] Reconnection error: $error');
    });

    _socket!.onError((error) {
      debugPrint('❌ [SocketService] Error: $error');
    });

    // Connect manually
    _socket!.connect();
  }

  /// Disconnect dari server.
  void disconnect() {
    debugPrint('🔌 [SocketService] Disconnecting...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Bergabung ke room event tertentu.
  /// Backend akan memasukkan socket ke room `event:{eventId}`.
  void joinEvent(String eventId) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('⚠️ [SocketService] Cannot joinEvent — not connected.');
      return;
    }
    debugPrint('📡 [SocketService] Joining event: $eventId');
    _socket!.emit('joinEvent', eventId);
  }

  /// Keluar dari room event.
  void leaveEvent(String eventId) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('⚠️ [SocketService] Cannot leaveEvent — not connected.');
      return;
    }
    debugPrint('📡 [SocketService] Leaving event: $eventId');
    _socket!.emit('leaveEvent', eventId);
  }

  /// Listen untuk event attendanceUpdated.
  /// Callback dipanggil dengan eventId saat ada absensi baru.
  void onAttendanceUpdated(void Function(String eventId) callback) {
    _socket?.on('attendanceUpdated', (data) {
      debugPrint('📬 [SocketService] attendanceUpdated received: $data');
      if (data is Map && data['eventId'] != null) {
        callback(data['eventId'] as String);
      }
    });
  }

  /// Hapus listener attendanceUpdated (untuk cleanup di dispose).
  void offAttendanceUpdated() {
    _socket?.off('attendanceUpdated');
  }
}

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_config.dart';

/// Service untuk mengelola koneksi Socket.IO ke backend.
/// Menggunakan socket_io_client v3.x dengan OptionBuilder().
class SocketService {
  IO.Socket? _socket;

  // Track joined rooms agar bisa re-join saat reconnect
  String? _currentUserId;
  String? _currentEventId;

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
      // Re-join rooms setelah reconnect
      _rejoinRooms();
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

  /// Re-join semua room setelah reconnect.
  void _rejoinRooms() {
    if (_currentUserId != null) {
      debugPrint('🔄 [SocketService] Re-joining user room: $_currentUserId');
      _socket!.emit('joinUserRoom', _currentUserId);
    }
    if (_currentEventId != null) {
      debugPrint('🔄 [SocketService] Re-joining event room: $_currentEventId');
      _socket!.emit('joinEvent', _currentEventId);
    }
  }

  /// Disconnect dari server.
  void disconnect() {
    debugPrint('🔌 [SocketService] Disconnecting...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ──────────────────────────────────────────────
  // User Room (untuk event list updates)
  // ──────────────────────────────────────────────

  /// Bergabung ke room user untuk menerima event list updates.
  /// Dipanggil setelah login berhasil.
  void joinUserRoom(String userId) {
    _currentUserId = userId;
    if (_socket == null || !_socket!.connected) {
      debugPrint('⚠️ [SocketService] Cannot joinUserRoom — not connected. Will join on connect.');
      return;
    }
    debugPrint('📡 [SocketService] Joining user room: $userId');
    _socket!.emit('joinUserRoom', userId);
  }

  /// Keluar dari room user.
  void leaveUserRoom() {
    if (_currentUserId != null && _socket != null && _socket!.connected) {
      debugPrint('📡 [SocketService] Leaving user room: $_currentUserId');
      _socket!.emit('leaveUserRoom', _currentUserId);
    }
    _currentUserId = null;
  }

  /// Listen untuk event list updated (create, update, delete event).
  void onEventListUpdated(void Function() callback) {
    _socket?.on('eventListUpdated', (data) {
      debugPrint('📬 [SocketService] eventListUpdated received: $data');
      callback();
    });
  }

  /// Hapus listener eventListUpdated.
  void offEventListUpdated() {
    _socket?.off('eventListUpdated');
  }

  // ──────────────────────────────────────────────
  // Event Room (untuk attendance updates)
  // ──────────────────────────────────────────────

  /// Bergabung ke room event tertentu.
  /// Backend akan memasukkan socket ke room `event:{eventId}`.
  void joinEvent(String eventId) {
    _currentEventId = eventId;
    if (_socket == null || !_socket!.connected) {
      debugPrint('⚠️ [SocketService] Cannot joinEvent — not connected. Will join on connect.');
      return;
    }
    debugPrint('📡 [SocketService] Joining event: $eventId');
    _socket!.emit('joinEvent', eventId);
  }

  /// Keluar dari room event.
  void leaveEvent(String eventId) {
    _currentEventId = null;
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

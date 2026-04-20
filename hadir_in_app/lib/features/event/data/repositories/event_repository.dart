import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/event_model.dart';
import '../models/event_detail_models.dart';

class EventRepository {
  final DioClient _dioClient;

  EventRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  String _getErrorMessage(DioException e, String defaultMsg) {
    if (e.response?.data is Map<String, dynamic>) {
      return e.response?.data['message'] as String? ?? defaultMsg;
    }
    return defaultMsg;
  }

  // ─── GET /api/events ─── Ambil semua event milik user yang login
  Future<List<EventModel>> getMyEvents() async {
    try {
      final response = await _dioClient.dio.get('/events');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal memuat daftar event'));
    }
  }

  // ─── POST /api/events ─── Buat event baru
  Future<EventModel> createEvent({
    required String name,
    required String description,
    required DateTime date,
    String? contactEmail,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/events',
        data: {
          'name': name,
          'description': description,
          'date': date.toIso8601String(),
          'contactEmail': contactEmail,
          'latitude': ?latitude,
          'longitude': ?longitude,
        },
      );
      return EventModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal membuat event'));
    }
  }

  // ─── GET /api/participants/:eventId ─── Daftar peserta event
  Future<List<ParticipantModel>> getParticipants(String eventId) async {
    try {
      final response = await _dioClient.dio.get('/participants/$eventId');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map(
            (json) => ParticipantModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal memuat peserta'));
    }
  }

  // ─── GET /api/attendance/:eventId ─── Log kehadiran event
  Future<List<AttendanceLogModel>> getAttendanceLogs(String eventId) async {
    try {
      final response = await _dioClient.dio.get('/attendance/$eventId');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map(
            (json) => AttendanceLogModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal memuat log kehadiran'));
    }
  }

  // ─── POST /api/participants/manual ─── Tambah peserta manual
  Future<void> addParticipantManual({
    required String eventId,
    required String name,
    required String email,
    String? noTelp,
  }) async {
    try {
      await _dioClient.dio.post(
        '/participants/manual',
        data: {
          'eventId': eventId,
          'name': name,
          'email': email,
          'noTelp': ?noTelp,
        },
      );
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal mendaftarkan peserta'));
    }
  }

  // ─── POST /api/participants/bulk ─── Tambah peserta via CSV
  Future<void> addParticipantBulk({
    required String eventId,
    required String filePath,
  }) async {
    try {
      final fileName = filePath.split(RegExp(r'[\\/]')).last;

      final formData = FormData.fromMap({
        'eventId': eventId,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      await _dioClient.dio.post(
        '/participants/bulk',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal mengimpor file CSV'));
    }
  }

  // ─── POST /api/attendance/scan ─── Scan Tiket Kehadiran
  Future<void> scanAttendance({
    required String eventId,
    required String ticketId,
  }) async {
    try {
      await _dioClient.dio.post(
        '/attendance/scan',
        data: {'eventId': eventId, 'ticketId': ticketId},
      );
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal melakukan scan tiket'));
    }
  }

  // ─── POST /api/participants/:eventId/blast ─── Kirim E-Ticket Massal
  Future<void> blastTickets(String eventId, {int? startIndex, int? endIndex}) async {
    try {
      final data = <String, dynamic>{};
      if (startIndex != null && endIndex != null) {
        data['startIndex'] = startIndex;
        data['endIndex'] = endIndex;
      }
      await _dioClient.dio.post('/participants/$eventId/blast', data: data);
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal melakukan pengiriman tiket'));
    }
  }

  // ─── POST /api/events/:eventId/template ─── Upload Gambar Template Tiket
  Future<void> uploadTemplate(String eventId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      await _dioClient.dio.post('/events/$eventId/template', data: formData);
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal mengunggah template tiket'));
    }
  }

  // ─── PUT /api/events/:eventId/template-config ─── Set Koordinat Layout
  Future<void> updateTemplateConfig({
    required String eventId,
    required Map<String, dynamic> config,
  }) async {
    try {
      await _dioClient.dio.put(
        '/events/$eventId/template-config',
        data: config,
      );
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Gagal menyimpan konfigurasi desain'),
      );
    }
  }

  // ─── GET /api/events/:eventId/template ─── Ambil Template Tersimpan
  Future<Map<String, dynamic>?> getEventTemplate(String eventId) async {
    try {
      final response = await _dioClient.dio.get('/events/$eventId/template');
      final data = response.data['data'] as Map<String, dynamic>?;
      return data;
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal mengambil template'));
    }
  }

  // ─── POST /api/events/join/:code ─── Bergabung Event sebagai Panitia
  Future<String> joinEvent(String code) async {
    try {
      final response = await _dioClient.dio.post('/events/join/$code');
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal bergabung event'));
    }
  }

  // ─── PUT /api/events/:eventId ─── Update Event
  Future<void> updateEvent({
    required String eventId,
    String? name,
    String? description,
    DateTime? date,
    String? contactEmail,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _dioClient.dio.put(
        '/events/$eventId',
        data: {
          'name': name,
          'description': description,
          if (date != null) 'date': date.toIso8601String(),
          'contactEmail': contactEmail,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal memperbarui event'));
    }
  }

  // ─── DELETE /api/events/:eventId ─── Hapus Event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _dioClient.dio.delete('/events/$eventId');
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal menghapus event'));
    }
  }

  // ─── POST /api/events/:eventId/image ─── Upload Gambar Banner Event
  Future<void> uploadEventImage(String eventId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      await _dioClient.dio.post('/events/$eventId/image', data: formData);
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal mengunggah gambar event'));
    }
  }

  // ─── PUT /api/participants/:id ─── Update Peserta
  Future<void> updateParticipant({
    required String id,
    String? name,
    String? email,
    String? noTelp,
  }) async {
    try {
      await _dioClient.dio.put(
        '/participants/$id',
        data: {'name': ?name, 'email': ?email, 'noTelp': ?noTelp},
      );
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal memperbarui peserta'));
    }
  }

  // ─── DELETE /api/participants/:id ─── Hapus Peserta
  Future<void> deleteParticipant(String id) async {
    try {
      await _dioClient.dio.delete('/participants/$id');
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal menghapus peserta'));
    }
  }

  // ─── POST /api/participants/:id/send-ticket ─── Kirim Tiket ke 1 Peserta
  Future<String> sendTicketToParticipant(String participantId) async {
    try {
      final response = await _dioClient.dio.post(
        '/participants/$participantId/send-ticket',
      );
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal mengirim tiket'));
    }
  }

  // ─── DELETE /api/attendance/logs/:logId ─── Hapus Log Absensi
  Future<void> deleteAttendanceLog(String logId) async {
    try {
      await _dioClient.dio.delete('/attendance/logs/$logId');
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Gagal menghapus log absensi'));
    }
  }
}


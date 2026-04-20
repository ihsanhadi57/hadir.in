/// Model Participant — cocok dengan response GET /api/participants/:eventId
class ParticipantModel {
  final String id;
  final String eventId;
  final String name;
  final String email;
  final String ticketId;
  final String? noTelp;
  final String status; // 'unused' | 'used'
  final DateTime createdAt;

  const ParticipantModel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.email,
    required this.ticketId,
    this.noTelp,
    required this.status,
    required this.createdAt,
  });

  bool get hasCheckedIn => status == 'used';

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      ticketId: json['ticketId'] as String,
      noTelp: json['noTelp'] as String?,
      status: json['status'] as String? ?? 'unused',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Model AttendanceLog — cocok dengan response GET /api/attendance/:eventId
class AttendanceLogModel {
  final String id;
  final String eventId;
  final String participantId;
  final String? scannedById;
  final DateTime scannedAt;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;

  // From include: participant
  final String? participantName;
  final String? participantEmail;
  final String? participantTicketId;

  const AttendanceLogModel({
    required this.id,
    required this.eventId,
    required this.participantId,
    this.scannedById,
    required this.scannedAt,
    this.latitude,
    this.longitude,
    this.participantName,
    this.participantEmail,
    this.participantTicketId,
    this.photoUrl,
  });

  factory AttendanceLogModel.fromJson(Map<String, dynamic> json) {
    final participant = json['participant'] as Map<String, dynamic>?;
    return AttendanceLogModel(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      participantId: json['participantId'] as String,
      scannedById: json['scannedById'] as String?,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      participantName: participant?['name'] as String?,
      participantEmail: participant?['email'] as String?,
      participantTicketId: participant?['ticketId'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  /// Relative time string (e.g. "Baru saja", "2 mnt lalu")
  String get relativeTime {
    final diff = DateTime.now().difference(scannedAt);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

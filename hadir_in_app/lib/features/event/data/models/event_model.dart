import '../../../../core/constants/api_config.dart';

/// Model Event — cocok dengan response dari backend Node.js
class EventModel {
  final String id;
  final String organizerId;
  final String name;
  final String? description;
  final String? contactEmail;
  final DateTime date;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? inviteCode;
  final DateTime createdAt;

  // Field yang dihitung dari relasi (participant count)
  // Backend saat ini tidak mengembalikan ini, jadi default 0
  final int totalParticipants;
  final int checkedIn;

  const EventModel({
    required this.id,
    required this.organizerId,
    required this.name,
    this.description,
    this.contactEmail,
    required this.date,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.inviteCode,
    required this.createdAt,
    this.totalParticipants = 0,
    this.checkedIn = 0,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      organizerId: json['organizerId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      contactEmail: json['contactEmail'] as String?,
      date: DateTime.parse(json['date'] as String),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      imageUrl: json['imageUrl'] != null
          ? (json['imageUrl'] as String).startsWith('http')
              ? json['imageUrl'] as String
              : '${ApiConfig.baseUrl}/${(json['imageUrl'] as String).replaceFirst('uploads/', 'uploads/')}'
          : null,
      inviteCode: json['inviteCode'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      totalParticipants: json['totalParticipants'] as int? ?? 0,
      checkedIn: json['checkedIn'] as int? ?? 0,
    );
  }

  /// Tentukan status berdasarkan tanggal
  EventStatus get status {
    final now = DateTime.now();
    final eventDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    if (eventDay.isAfter(today)) return EventStatus.upcoming;
    if (eventDay.isAtSameMomentAs(today)) return EventStatus.active;
    return EventStatus.ended;
  }
}

enum EventStatus { upcoming, active, ended }

extension EventStatusX on EventStatus {
  String get label {
    switch (this) {
      case EventStatus.upcoming:
        return 'UPCOMING';
      case EventStatus.active:
        return 'LIVE';
      case EventStatus.ended:
        return 'SELESAI';
    }
  }
}

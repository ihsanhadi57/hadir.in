class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final int emailQuota;
  final int totalEmailsSent;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.emailQuota,
    required this.totalEmailsSent,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'organizer',
      emailQuota: json['emailQuota'] as int? ?? 50,
      totalEmailsSent: json['totalEmailsSent'] as int? ?? 0,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'emailQuota': emailQuota,
        'totalEmailsSent': totalEmailsSent,
        'avatarUrl': avatarUrl,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    int? emailQuota,
    int? totalEmailsSent,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      emailQuota: emailQuota ?? this.emailQuota,
      totalEmailsSent: totalEmailsSent ?? this.totalEmailsSent,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

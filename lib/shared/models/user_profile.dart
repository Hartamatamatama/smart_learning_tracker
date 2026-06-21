class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.timezone = 'Asia/Jakarta',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => fullName?.trim().isNotEmpty == true ? fullName! : 'Pelajar';

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'timezone': timezone,
      };

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    String? timezone,
  }) =>
      UserProfile(
        id: id,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        timezone: timezone ?? this.timezone,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

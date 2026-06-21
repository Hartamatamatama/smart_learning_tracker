/// Topik / mata pelajaran yang dibuat user. Berelasi ke tabel `topics`.
class Topic {
  const Topic({
    required this.id,
    required this.userId,
    required this.name,
    this.colorHex = '#4A90D9',
    this.iconName,
    this.isArchived = false,
    required this.createdAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        colorHex: json['color_hex'] as String? ?? '#4A90D9',
        iconName: json['icon_name'] as String?,
        isArchived: json['is_archived'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String userId;
  final String name;
  final String colorHex;
  final String? iconName;
  final bool isArchived;
  final DateTime createdAt;
}

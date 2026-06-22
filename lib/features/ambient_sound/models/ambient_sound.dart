/// Katalog ambient sound (tabel `ambient_sounds`).
/// `filePath` menunjuk ke asset bundel Flutter, mis. 'assets/sounds/rain.mp3'.
class AmbientSound {
  const AmbientSound({
    required this.id,
    required this.name,
    this.description,
    required this.filePath,
    this.category = 'nature',
    this.sortOrder = 0,
  });

  factory AmbientSound.fromJson(Map<String, dynamic> json) => AmbientSound(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        filePath: json['file_path'] as String,
        category: json['category'] as String? ?? 'nature',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final String? description;
  final String filePath;
  final String category;
  final int sortOrder;
}

/// Parameter mood global (tabel `mood_parameters`).
/// Seed bawaan: mood_umum, fokus, kelelahan, motivasi.
class MoodParameter {
  const MoodParameter({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
    this.scaleMin = 1,
    this.scaleMax = 5,
    this.sortOrder = 0,
  });

  factory MoodParameter.fromJson(Map<String, dynamic> json) => MoodParameter(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        iconName: json['icon_name'] as String?,
        scaleMin: (json['scale_min'] as num?)?.toInt() ?? 1,
        scaleMax: (json['scale_max'] as num?)?.toInt() ?? 5,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final String? description;
  final String? iconName;
  final int scaleMin;
  final int scaleMax;
  final int sortOrder;

  /// Label tampilan yang ramah (judul kartu di form jurnal).
  String get displayLabel => displayLabelFor(name);

  /// Versi statis — dipakai saat hanya punya nama parameter (mis. di repo).
  static String displayLabelFor(String name) => switch (name) {
        'mood_umum' => 'Mood Umum',
        'fokus' => 'Fokus',
        'kelelahan' => 'Kelelahan',
        'motivasi' => 'Motivasi',
        _ => name.isEmpty
            ? name
            : name[0].toUpperCase() + name.substring(1).replaceAll('_', ' '),
      };
}

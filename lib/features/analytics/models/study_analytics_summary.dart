/// Rentang waktu dalam sehari, untuk mengelompokkan kebiasaan belajar.
enum TimeOfDayBucket {
  pagi, // 05:00–10:59
  siang, // 11:00–14:59
  sore, // 15:00–17:59
  malam; // 18:00–04:59

  String get label => switch (this) {
        TimeOfDayBucket.pagi => 'Pagi',
        TimeOfDayBucket.siang => 'Siang',
        TimeOfDayBucket.sore => 'Sore',
        TimeOfDayBucket.malam => 'Malam',
      };

  static TimeOfDayBucket fromHour(int hour) {
    if (hour >= 5 && hour < 11) return TimeOfDayBucket.pagi;
    if (hour >= 11 && hour < 15) return TimeOfDayBucket.siang;
    if (hour >= 15 && hour < 18) return TimeOfDayBucket.sore;
    return TimeOfDayBucket.malam;
  }

  static TimeOfDayBucket fromName(String name) =>
      TimeOfDayBucket.values.firstWhere((e) => e.name == name,
          orElse: () => TimeOfDayBucket.malam);
}

/// Rata-rata mood per parameter untuk satu topik.
class TopicMoodAverage {
  const TopicMoodAverage({
    required this.topicName,
    required this.sessionCount,
    required this.averageByParameter,
  });

  final String topicName;
  final int sessionCount;

  /// Key = nama parameter (mood_umum, fokus, kelelahan, motivasi).
  final Map<String, double> averageByParameter;

  Map<String, dynamic> toJson() => {
        'topicName': topicName,
        'sessionCount': sessionCount,
        'averageByParameter': averageByParameter,
      };

  factory TopicMoodAverage.fromJson(Map<String, dynamic> j) => TopicMoodAverage(
        topicName: j['topicName'] as String,
        sessionCount: (j['sessionCount'] as num).toInt(),
        averageByParameter: (j['averageByParameter'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble())),
      );
}

/// Satu titik tren mood (per hari atau per minggu), fokus sebagai representatif.
class MoodTrendPoint {
  const MoodTrendPoint({
    required this.label,
    required this.fokus,
    required this.sessionCount,
  });

  final String label;
  final double fokus;
  final int sessionCount;

  Map<String, dynamic> toJson() =>
      {'label': label, 'fokus': fokus, 'sessionCount': sessionCount};

  factory MoodTrendPoint.fromJson(Map<String, dynamic> j) => MoodTrendPoint(
        label: j['label'] as String,
        fokus: (j['fokus'] as num).toDouble(),
        sessionCount: (j['sessionCount'] as num).toInt(),
      );
}

/// Ringkasan analitik belajar dalam periode tertentu.
/// Jadi input prompt AI (Fase 5) sekaligus sumber data grafik laporan.
class StudyAnalyticsSummary {
  const StudyAnalyticsSummary({
    required this.periodDays,
    required this.sessionCount,
    required this.totalMinutes,
    required this.completedCount,
    required this.stoppedEarlyCount,
    required this.averageMoodByParameter,
    required this.topicMoodAverages,
    required this.sessionsByTimeOfDay,
    this.minutesByTopic = const {},
    this.moodTrend = const [],
  });

  final int periodDays;
  final int sessionCount;
  final int totalMinutes;
  final int completedCount;
  final int stoppedEarlyCount;

  /// Rata-rata skor (1-5) per parameter mood, seluruh sesi di periode.
  final Map<String, double> averageMoodByParameter;

  /// Rata-rata mood per topik.
  final List<TopicMoodAverage> topicMoodAverages;

  /// Jumlah sesi per rentang waktu hari.
  final Map<TimeOfDayBucket, int> sessionsByTimeOfDay;

  /// Total menit belajar per topik (untuk bar chart).
  final Map<String, int> minutesByTopic;

  /// Tren fokus per hari/minggu (untuk line chart), urut lama → baru.
  final List<MoodTrendPoint> moodTrend;

  /// Rentang waktu paling sering dipakai belajar (null jika tak ada sesi).
  TimeOfDayBucket? get busiestTimeOfDay {
    if (sessionsByTimeOfDay.isEmpty) return null;
    return sessionsByTimeOfDay.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
  }

  bool get isEmpty => sessionCount == 0;

  // ---- Serialisasi (disimpan sebagai snapshot di ai_evaluations.summary_json)

  Map<String, dynamic> toJson() => {
        'periodDays': periodDays,
        'sessionCount': sessionCount,
        'totalMinutes': totalMinutes,
        'completedCount': completedCount,
        'stoppedEarlyCount': stoppedEarlyCount,
        'averageMoodByParameter': averageMoodByParameter,
        'topicMoodAverages': topicMoodAverages.map((e) => e.toJson()).toList(),
        'sessionsByTimeOfDay': {
          for (final e in sessionsByTimeOfDay.entries) e.key.name: e.value
        },
        'minutesByTopic': minutesByTopic,
        'moodTrend': moodTrend.map((e) => e.toJson()).toList(),
      };

  factory StudyAnalyticsSummary.fromJson(Map<String, dynamic> j) =>
      StudyAnalyticsSummary(
        periodDays: (j['periodDays'] as num).toInt(),
        sessionCount: (j['sessionCount'] as num).toInt(),
        totalMinutes: (j['totalMinutes'] as num).toInt(),
        completedCount: (j['completedCount'] as num).toInt(),
        stoppedEarlyCount: (j['stoppedEarlyCount'] as num).toInt(),
        averageMoodByParameter:
            (j['averageMoodByParameter'] as Map? ?? {}).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble())),
        topicMoodAverages: ((j['topicMoodAverages'] as List?) ?? [])
            .map((e) => TopicMoodAverage.fromJson(e as Map<String, dynamic>))
            .toList(),
        sessionsByTimeOfDay: (j['sessionsByTimeOfDay'] as Map? ?? {}).map(
            (k, v) =>
                MapEntry(TimeOfDayBucket.fromName(k as String), (v as num).toInt())),
        minutesByTopic: (j['minutesByTopic'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        moodTrend: ((j['moodTrend'] as List?) ?? [])
            .map((e) => MoodTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Representasi teks ringkas — bahan utama prompt AI.
  String describe() {
    if (isEmpty) return 'Belum ada sesi dalam $periodDays hari terakhir.';
    final buf = StringBuffer()
      ..writeln('Ringkasan $periodDays hari terakhir:')
      ..writeln('- Total sesi: $sessionCount '
          '($completedCount selesai, $stoppedEarlyCount dihentikan)')
      ..writeln('- Total menit belajar: $totalMinutes')
      ..writeln('- Rata-rata mood (skala 1-5):');
    for (final e in averageMoodByParameter.entries) {
      buf.writeln('    ${e.key}: ${e.value.toStringAsFixed(2)}');
    }
    buf.writeln('- Menit & mood per topik:');
    for (final t in topicMoodAverages) {
      final mins = minutesByTopic[t.topicName] ?? 0;
      final parts = t.averageByParameter.entries
          .map((e) => '${e.key} ${e.value.toStringAsFixed(1)}');
      buf.writeln('    ${t.topicName} (${t.sessionCount} sesi, $mins menit): '
          '${parts.join(", ")}');
    }
    buf.write('- Sesi per waktu: ');
    buf.writeln(sessionsByTimeOfDay.entries
        .map((e) => '${e.key.label} ${e.value}')
        .join(', '));
    buf.write('- Paling sering belajar: ${busiestTimeOfDay?.label ?? "-"}');
    return buf.toString();
  }
}

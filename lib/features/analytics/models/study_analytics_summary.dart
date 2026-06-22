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
}

/// Ringkasan analitik belajar dalam periode tertentu.
/// Disiapkan sebagai input prompt AI di Fase 5 (tidak ditampilkan di UI Fase 4).
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

  /// Rentang waktu paling sering dipakai belajar (null jika tak ada sesi).
  TimeOfDayBucket? get busiestTimeOfDay {
    if (sessionsByTimeOfDay.isEmpty) return null;
    return sessionsByTimeOfDay.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
  }

  bool get isEmpty => sessionCount == 0;

  /// Representasi teks ringkas — berguna untuk debugging & sebagai bahan
  /// prompt AI di Fase 5.
  String describe() {
    if (isEmpty) return 'Belum ada sesi dalam $periodDays hari terakhir.';
    final buf = StringBuffer()
      ..writeln('Ringkasan $periodDays hari terakhir:')
      ..writeln('- Total sesi: $sessionCount '
          '($completedCount selesai, $stoppedEarlyCount dihentikan)')
      ..writeln('- Total menit belajar: $totalMinutes')
      ..writeln('- Rata-rata mood:');
    for (final e in averageMoodByParameter.entries) {
      buf.writeln('    ${e.key}: ${e.value.toStringAsFixed(2)}');
    }
    buf.writeln('- Rata-rata mood per topik:');
    for (final t in topicMoodAverages) {
      final parts =
          t.averageByParameter.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(1)}');
      buf.writeln('    ${t.topicName} (${t.sessionCount} sesi): ${parts.join(", ")}');
    }
    buf.write('- Sesi per waktu: ');
    buf.writeln(sessionsByTimeOfDay.entries
        .map((e) => '${e.key.label} ${e.value}')
        .join(', '));
    buf.write('- Paling sering belajar: ${busiestTimeOfDay?.label ?? "-"}');
    return buf.toString();
  }
}

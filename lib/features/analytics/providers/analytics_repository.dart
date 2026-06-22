import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../models/study_analytics_summary.dart';

/// Menghitung agregat belajar untuk periode tertentu.
/// Dipakai sebagai input prompt AI di Fase 5 (belum ditampilkan di UI).
///
/// Agregasi dihitung di Dart atas data periode yang TERBATAS (mis. 30 hari),
/// jadi volume datanya kecil dan aman — berbeda dengan list riwayat yang
/// di-paginate di server.
class AnalyticsRepository {
  const AnalyticsRepository();

  String get _userId {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw StateError('Tidak ada user yang login.');
    return user.id;
  }

  Future<StudyAnalyticsSummary> computeSummary({int days = 30}) async {
    final since =
        DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

    // 1. Sesi dalam periode.
    final sessionRows = await SupabaseConfig.client
        .from('study_sessions')
        .select('id, started_at, actual_duration_sec, status, topics(name)')
        .eq('user_id', _userId)
        .gte('started_at', since);

    if (sessionRows.isEmpty) {
      return StudyAnalyticsSummary(
        periodDays: days,
        sessionCount: 0,
        totalMinutes: 0,
        completedCount: 0,
        stoppedEarlyCount: 0,
        averageMoodByParameter: const {},
        topicMoodAverages: const [],
        sessionsByTimeOfDay: const {},
      );
    }

    final sessionTopic = <String, String>{}; // sessionId -> topicName
    final sessionBucketKey = <String, int>{}; // sessionId -> trend bucket index
    final topicSessionCount = <String, int>{};
    final minutesByTopic = <String, int>{};
    var totalSeconds = 0;
    var completed = 0;
    var stoppedEarly = 0;
    final byTimeOfDay = <TimeOfDayBucket, int>{};

    // Tren dikelompokkan harian jika periode pendek, mingguan jika panjang,
    // supaya label tidak tumpang tindih di layar mobile.
    final groupByWeek = days > 10;
    final now = DateTime.now();
    final bucketLabel = <int, String>{};

    for (final row in sessionRows) {
      final id = row['id'] as String;
      final topicName =
          (row['topics'] as Map<String, dynamic>?)?['name'] as String? ??
              '(Topik dihapus)';
      sessionTopic[id] = topicName;
      topicSessionCount[topicName] = (topicSessionCount[topicName] ?? 0) + 1;
      final secs = (row['actual_duration_sec'] as num?)?.toInt() ?? 0;
      totalSeconds += secs;
      minutesByTopic[topicName] =
          (minutesByTopic[topicName] ?? 0) + (secs / 60).round();
      final status = row['status'] as String? ?? 'completed';
      if (status == 'completed') {
        completed++;
      } else {
        stoppedEarly++;
      }
      final started = DateTime.parse(row['started_at'] as String).toLocal();
      byTimeOfDay[TimeOfDayBucket.fromHour(started.hour)] =
          (byTimeOfDay[TimeOfDayBucket.fromHour(started.hour)] ?? 0) + 1;

      // Indeks bucket tren: kecil = lama, besar = baru.
      final daysAgo = now.difference(started).inDays;
      final key = groupByWeek ? (days - 1 - daysAgo) ~/ 7 : (days - 1 - daysAgo);
      sessionBucketKey[id] = key;
      bucketLabel[key] = groupByWeek
          ? 'Mgg ${key + 1}'
          : '${started.day}/${started.month}';
    }

    // 2. Mood untuk sesi-sesi tersebut.
    final ids = sessionTopic.keys.toList();
    final moodRows = await SupabaseConfig.client
        .from('mood_journals')
        .select('session_id, score, mood_parameters(name)')
        .inFilter('session_id', ids);

    // Akumulator rata-rata global per parameter.
    final paramSum = <String, int>{};
    final paramCount = <String, int>{};
    // Akumulator per topik per parameter.
    final topicParamSum = <String, Map<String, int>>{};
    final topicParamCount = <String, Map<String, int>>{};
    // Akumulator tren fokus per bucket waktu.
    final bucketFokusSum = <int, int>{};
    final bucketFokusCount = <int, int>{};
    final bucketSessions = <int, Set<String>>{};

    for (final row in moodRows) {
      final paramName =
          (row['mood_parameters'] as Map<String, dynamic>?)?['name'] as String? ??
              '';
      if (paramName.isEmpty) continue;
      final score = (row['score'] as num?)?.toInt() ?? 0;
      paramSum[paramName] = (paramSum[paramName] ?? 0) + score;
      paramCount[paramName] = (paramCount[paramName] ?? 0) + 1;

      final sessionId = row['session_id'] as String;
      final topic = sessionTopic[sessionId] ?? '(?)';
      (topicParamSum[topic] ??= {})[paramName] =
          ((topicParamSum[topic] ??= {})[paramName] ?? 0) + score;
      (topicParamCount[topic] ??= {})[paramName] =
          ((topicParamCount[topic] ??= {})[paramName] ?? 0) + 1;

      if (paramName == 'fokus') {
        final key = sessionBucketKey[sessionId];
        if (key != null) {
          bucketFokusSum[key] = (bucketFokusSum[key] ?? 0) + score;
          bucketFokusCount[key] = (bucketFokusCount[key] ?? 0) + 1;
          (bucketSessions[key] ??= {}).add(sessionId);
        }
      }
    }

    final moodTrend = (bucketFokusSum.keys.toList()..sort())
        .map((k) => MoodTrendPoint(
              label: bucketLabel[k] ?? '$k',
              fokus: bucketFokusSum[k]! / bucketFokusCount[k]!,
              sessionCount: bucketSessions[k]?.length ?? 0,
            ))
        .toList();

    final avgByParameter = <String, double>{
      for (final p in paramSum.keys) p: paramSum[p]! / paramCount[p]!,
    };

    final topicAverages = <TopicMoodAverage>[];
    for (final topic in topicParamSum.keys) {
      final sums = topicParamSum[topic]!;
      final counts = topicParamCount[topic]!;
      topicAverages.add(TopicMoodAverage(
        topicName: topic,
        sessionCount: topicSessionCount[topic] ?? 0,
        averageByParameter: {
          for (final p in sums.keys) p: sums[p]! / counts[p]!,
        },
      ));
    }
    topicAverages.sort((a, b) => b.sessionCount.compareTo(a.sessionCount));

    return StudyAnalyticsSummary(
      periodDays: days,
      sessionCount: sessionRows.length,
      totalMinutes: (totalSeconds / 60).round(),
      completedCount: completed,
      stoppedEarlyCount: stoppedEarly,
      averageMoodByParameter: avgByParameter,
      topicMoodAverages: topicAverages,
      sessionsByTimeOfDay: byTimeOfDay,
      minutesByTopic: minutesByTopic,
      moodTrend: moodTrend,
    );
  }
}

final analyticsRepositoryProvider =
    Provider<AnalyticsRepository>((ref) => const AnalyticsRepository());

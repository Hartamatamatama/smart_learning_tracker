import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../mood/models/mood_parameter.dart';
import '../models/history_filter.dart';
import '../models/session_history_item.dart';

/// Query riwayat sesi dari Supabase. Filter & pagination dilakukan di sisi
/// server (bukan client) demi efisiensi saat data banyak.
class HistoryRepository {
  const HistoryRepository();

  static const int defaultPageSize = 10;

  String get _userId {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw StateError('Tidak ada user yang login.');
    return user.id;
  }

  /// Ambil satu halaman riwayat (sudah ter-join topik & ambient) + total count
  /// yang cocok dengan filter (untuk menghitung jumlah halaman).
  Future<HistoryPage> fetchPage({
    required HistoryFilter filter,
    required int pageIndex,
    int pageSize = defaultPageSize,
  }) async {
    final start = pageIndex * pageSize;
    final end = start + pageSize - 1;

    var query = SupabaseConfig.client
        .from('study_sessions')
        .select(
          'id, started_at, ended_at, actual_duration_sec, planned_duration_sec, '
          'mode, status, notes, topics(name), ambient_sounds(name)',
        )
        .eq('user_id', _userId);

    if (filter.topicIds.isNotEmpty) {
      query = query.inFilter('topic_id', filter.topicIds.toList());
    }
    if (filter.from != null) {
      query = query.gte('started_at', filter.from!.toUtc().toIso8601String());
    }
    if (filter.to != null) {
      query = query.lte('started_at', filter.to!.toUtc().toIso8601String());
    }
    if (filter.mode != null) {
      query = query.eq('mode', filter.mode!.dbValue);
    }

    final res = await query
        .order('started_at', ascending: false)
        .range(start, end)
        .count(CountOption.exact);

    final items = res.data
        .map((e) => SessionHistoryItem.fromJson(e))
        .toList();

    return HistoryPage(
      items: items,
      totalCount: res.count,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  /// Rekap mood satu sesi (join mood_journals × mood_parameters).
  Future<SessionMoodDetail> fetchSessionMoods(String sessionId) async {
    final rows = await SupabaseConfig.client
        .from('mood_journals')
        .select('score, note, mood_parameters(name, sort_order)')
        .eq('session_id', sessionId);

    String? note;
    final scores = <SessionMoodScore>[];
    for (final row in rows) {
      final param = row['mood_parameters'] as Map<String, dynamic>?;
      final name = param?['name'] as String? ?? '';
      final rowNote = row['note'] as String?;
      if (rowNote != null && rowNote.trim().isNotEmpty) note = rowNote.trim();
      scores.add(SessionMoodScore(
        parameterName: name,
        displayLabel: MoodParameter.displayLabelFor(name),
        score: (row['score'] as num?)?.toInt() ?? 0,
        sortOrder: (param?['sort_order'] as num?)?.toInt() ?? 0,
      ));
    }
    scores.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return SessionMoodDetail(scores: scores, note: note);
  }
}

final historyRepositoryProvider =
    Provider<HistoryRepository>((ref) => const HistoryRepository());

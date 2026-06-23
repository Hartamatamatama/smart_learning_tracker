import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../models/study_session.dart';

/// Satu nilai mood untuk satu parameter dalam sebuah sesi.
class MoodEntry {
  const MoodEntry({
    required this.parameterId,
    required this.score,
    this.note,
  });

  final String parameterId;
  final int score;

  /// Catatan teks bebas. Biasanya hanya diisi pada satu parameter
  /// (mood_umum) agar tidak duplikat di 4 baris.
  final String? note;
}

/// Repository untuk menyimpan hasil sesi belajar & jurnal mood ke Supabase.
class SessionRepository {
  const SessionRepository();

  String get _userId {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      throw StateError('Tidak ada user yang login.');
    }
    return user.id;
  }

  /// Apakah user sudah punya minimal 1 sesi belajar HARI INI (zona waktu lokal)?
  /// Dipakai logic reminder: kalau sudah belajar, reminder sisa hari dibatalkan.
  /// started_at disimpan UTC, jadi bandingkan dengan tengah-malam lokal → UTC.
  Future<bool> hasSessionToday() async {
    final now = DateTime.now();
    final localMidnightUtc =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final rows = await SupabaseConfig.client
        .from('study_sessions')
        .select('id')
        .eq('user_id', _userId)
        .gte('started_at', localMidnightUtc)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Insert satu baris study_session, kembalikan id-nya.
  Future<String> insertSession(StudySession session) async {
    final inserted = await SupabaseConfig.client
        .from('study_sessions')
        .insert(session.toInsertJson())
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  /// Simpan beberapa nilai mood sekaligus (1 baris per parameter).
  /// Unique(session_id, mood_parameter_id) dijaga skema DB.
  Future<void> insertMoodJournals({
    required String sessionId,
    required List<MoodEntry> entries,
  }) async {
    final userId = _userId;
    final rows = entries
        .map((e) => {
              'user_id': userId,
              'session_id': sessionId,
              'mood_parameter_id': e.parameterId,
              'score': e.score,
              'note': e.note,
            })
        .toList();
    await SupabaseConfig.client.from('mood_journals').insert(rows);
  }
}

final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => const SessionRepository());

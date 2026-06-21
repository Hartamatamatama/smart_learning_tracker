import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../../../core/constants/app_constants.dart';
import '../models/study_session.dart';

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

  /// Insert satu baris study_session, kembalikan id-nya.
  Future<String> insertSession(StudySession session) async {
    final inserted = await SupabaseConfig.client
        .from('study_sessions')
        .insert(session.toInsertJson())
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  /// Ambil id parameter mood default ('mood_umum') dari tabel global.
  Future<String> defaultMoodParameterId() async {
    final row = await SupabaseConfig.client
        .from('mood_parameters')
        .select('id')
        .eq('name', AppConstants.defaultMoodParameter)
        .single();
    return row['id'] as String;
  }

  /// Simpan satu nilai mood (placeholder Fase 2: 1 parameter saja).
  Future<void> insertMoodJournal({
    required String sessionId,
    required int score,
    String? note,
  }) async {
    final parameterId = await defaultMoodParameterId();
    await SupabaseConfig.client.from('mood_journals').insert({
      'user_id': _userId,
      'session_id': sessionId,
      'mood_parameter_id': parameterId,
      'score': score,
      'note': note,
    });
  }
}

final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => const SessionRepository());

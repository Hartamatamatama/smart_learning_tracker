import 'timer_enums.dart';

/// Data satu sesi belajar yang disimpan ke tabel `study_sessions`.
///
/// Satu baris dibuat sekali saat sesi BERAKHIR (bukan saat mulai), supaya
/// tidak ada baris `in_progress` menggantung. Durasi aktual dihitung dari
/// selisih timestamp, bukan dari counter UI.
class StudySession {
  const StudySession({
    this.id,
    required this.userId,
    required this.topicId,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.plannedDurationSec,
    required this.actualDurationSec,
    required this.status,
    this.ambientSoundId,
  });

  final String? id;
  final String userId;
  final String topicId;
  final TimerMode mode;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Hanya untuk Pomodoro. Null untuk Stopwatch.
  final int? plannedDurationSec;

  /// Durasi aktual yang benar-benar berjalan (detik), dari timestamp.
  final int actualDurationSec;
  final SessionStatus status;

  /// Ambient sound yang dipakai selama sesi. Null jika "Tanpa suara".
  final String? ambientSoundId;

  /// Payload untuk INSERT ke Supabase.
  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'topic_id': topicId,
        'mode': mode.dbValue,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'planned_duration_sec': plannedDurationSec,
        'actual_duration_sec': actualDurationSec,
        'status': status.dbValue,
        'ambient_sound_id': ambientSoundId,
      };
}

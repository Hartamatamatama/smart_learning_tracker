import '../../timer/models/timer_enums.dart';

/// Satu baris riwayat sesi (hasil join study_sessions × topics × ambient_sounds).
class SessionHistoryItem {
  const SessionHistoryItem({
    required this.id,
    required this.topicName,
    required this.ambientName,
    required this.startedAt,
    required this.endedAt,
    required this.actualDurationSec,
    required this.plannedDurationSec,
    required this.mode,
    required this.status,
    this.notes,
  });

  factory SessionHistoryItem.fromJson(Map<String, dynamic> json) {
    final topic = json['topics'] as Map<String, dynamic>?;
    final ambient = json['ambient_sounds'] as Map<String, dynamic>?;
    return SessionHistoryItem(
      id: json['id'] as String,
      topicName: topic?['name'] as String? ?? '(Topik dihapus)',
      ambientName: ambient?['name'] as String?, // null = Tanpa suara
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String).toLocal()
          : null,
      actualDurationSec: (json['actual_duration_sec'] as num?)?.toInt() ?? 0,
      plannedDurationSec: (json['planned_duration_sec'] as num?)?.toInt(),
      mode: TimerMode.fromDb(json['mode'] as String? ?? 'pomodoro'),
      status: SessionStatus.fromDb(json['status'] as String? ?? 'completed'),
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String topicName;

  /// Null artinya "Tanpa suara".
  final String? ambientName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int actualDurationSec;
  final int? plannedDurationSec;
  final TimerMode mode;
  final SessionStatus status;
  final String? notes;

  String get ambientLabel => ambientName ?? 'Tanpa suara';
}

/// Nilai mood satu parameter untuk detail sesi.
class SessionMoodScore {
  const SessionMoodScore({
    required this.parameterName,
    required this.displayLabel,
    required this.score,
    required this.sortOrder,
  });

  final String parameterName;
  final String displayLabel;
  final int score;
  final int sortOrder;
}

/// Rekap mood lengkap untuk satu sesi (4 parameter + catatan).
class SessionMoodDetail {
  const SessionMoodDetail({required this.scores, this.note});

  final List<SessionMoodScore> scores;
  final String? note;

  bool get isEmpty => scores.isEmpty;
}

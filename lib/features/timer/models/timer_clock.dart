/// Jam timer berbasis timestamp — bukan counter.
///
/// Inti akurasi fitur ini: berapa pun lama app di-background atau layar
/// dikunci, elapsed selalu dihitung dari selisih waktu nyata
/// (now - startedAt - totalPause), sehingga tidak pernah "freeze".
///
/// Class ini murni (tanpa dependency Flutter) dan bisa diserialisasi,
/// agar dipakai bersama oleh isolate foreground service dan fallback Web.
class TimerClock {
  TimerClock({
    required this.startedAtMs,
    this.accumulatedPauseMs = 0,
    this.pauseStartedAtMs,
  });

  /// Epoch millis saat sesi dimulai.
  final int startedAtMs;

  /// Total durasi pause yang sudah selesai (millis).
  int accumulatedPauseMs;

  /// Epoch millis saat pause dimulai. Null artinya sedang berjalan.
  int? pauseStartedAtMs;

  bool get isPaused => pauseStartedAtMs != null;

  /// Detik efektif yang sudah berjalan pada [nowMs].
  int elapsedSeconds(int nowMs) {
    var effectiveMs = nowMs - startedAtMs - accumulatedPauseMs;
    if (pauseStartedAtMs != null) {
      effectiveMs -= (nowMs - pauseStartedAtMs!);
    }
    if (effectiveMs < 0) effectiveMs = 0;
    return effectiveMs ~/ 1000;
  }

  void pause(int nowMs) {
    pauseStartedAtMs ??= nowMs;
  }

  void resume(int nowMs) {
    final startedPause = pauseStartedAtMs;
    if (startedPause != null) {
      accumulatedPauseMs += nowMs - startedPause;
      pauseStartedAtMs = null;
    }
  }

  Map<String, dynamic> toMap() => {
        'startedAtMs': startedAtMs,
        'accumulatedPauseMs': accumulatedPauseMs,
        'pauseStartedAtMs': pauseStartedAtMs,
      };

  factory TimerClock.fromMap(Map<String, dynamic> map) => TimerClock(
        startedAtMs: map['startedAtMs'] as int,
        accumulatedPauseMs: (map['accumulatedPauseMs'] as int?) ?? 0,
        pauseStartedAtMs: map['pauseStartedAtMs'] as int?,
      );
}

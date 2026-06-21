class DurationFormatter {
  DurationFormatter._();

  /// Mengubah detik menjadi string "MM:SS" atau "HH:MM:SS" jika >= 1 jam.
  static String fromSeconds(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Mengubah durasi menjadi label ringkas, misalnya "1j 25m".
  static String toReadable(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_time.dart';

/// Simpan daftar jadwal pengingat di shared_preferences sebagai list "HH:mm".
/// Format sengaja dibuat sederhana agar mudah di-loop ulang saat reschedule.
class ReminderPrefs {
  ReminderPrefs._();

  static const _key = 'study_reminder_times';

  static Future<List<ReminderTime>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final list =
        raw.map(ReminderTime.decode).whereType<ReminderTime>().toList();
    list.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return list;
  }

  static Future<void> save(List<ReminderTime> times) async {
    final prefs = await SharedPreferences.getInstance();
    // Dedup + urut agar konsisten.
    final encoded = times.map((t) => t.encode()).toSet().toList()..sort();
    await prefs.setStringList(_key, encoded);
  }
}

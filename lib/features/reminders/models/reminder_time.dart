import 'package:flutter/material.dart';

/// Satu jadwal pengingat belajar (jam:menit, zona waktu lokal).
@immutable
class ReminderTime {
  const ReminderTime({required this.hour, required this.minute});

  final int hour; // 0-23
  final int minute; // 0-59

  factory ReminderTime.fromTimeOfDay(TimeOfDay t) =>
      ReminderTime(hour: t.hour, minute: t.minute);

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  /// Id notifikasi stabil & unik per waktu-hari → memudahkan
  /// menjadwalkan / membatalkan. Offset 1000 agar tidak bentrok dengan id lain
  /// (mis. foreground service timer = 500).
  int get notificationId => 1000 + hour * 60 + minute;

  /// Total menit dari tengah malam — untuk pengurutan.
  int get minutesOfDay => hour * 60 + minute;

  /// Serialisasi ringkas "HH:mm" untuk shared_preferences.
  String encode() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ReminderTime? decode(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return ReminderTime(hour: h, minute: m);
  }

  /// Label sesuai preferensi format 12/24 jam device.
  String label(BuildContext context) => timeOfDay.format(context);

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

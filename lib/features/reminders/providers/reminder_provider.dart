import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../timer/providers/session_repository.dart';
import '../models/reminder_time.dart';
import '../services/reminder_prefs.dart';
import '../services/reminder_service.dart';

/// State: daftar jadwal pengingat belajar (sumber: shared_preferences).
class ReminderController extends AsyncNotifier<List<ReminderTime>> {
  @override
  Future<List<ReminderTime>> build() => ReminderPrefs.load();

  Future<void> addTime(ReminderTime t) async {
    final current = state.valueOrNull ?? const <ReminderTime>[];
    if (current.contains(t)) return;
    final next = [...current, t]
      ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    await ReminderPrefs.save(next);
    state = AsyncData(next);
    await reconcileToday();
  }

  Future<void> removeTime(ReminderTime t) async {
    final current = state.valueOrNull ?? const <ReminderTime>[];
    final next = current.where((e) => e != t).toList();
    await ReminderPrefs.save(next);
    state = AsyncData(next);
    // Batalkan notifikasi yang mungkin sudah dijadwalkan untuk waktu ini.
    await ReminderService.instance.cancelAll([t]);
    await reconcileToday();
  }

  /// Inti logic kondisional (dipanggil saat app dibuka & saat sesi selesai):
  /// - Sudah ada sesi belajar hari ini  → batalkan semua pengingat sisa hari.
  /// - Belum ada sesi hari ini          → jadwalkan ulang jam yang belum lewat.
  Future<void> reconcileToday() async {
    final times = state.valueOrNull ?? await ReminderPrefs.load();
    if (times.isEmpty) {
      await ReminderService.instance.cancelAll(times);
      return;
    }
    bool studiedToday;
    try {
      studiedToday =
          await ref.read(sessionRepositoryProvider).hasSessionToday();
    } catch (_) {
      // Gagal cek (mis. offline / belum login) → aman-kan dengan tetap
      // menjadwalkan; user masih bisa diingatkan.
      studiedToday = false;
    }
    if (studiedToday) {
      await ReminderService.instance.cancelAll(times);
    } else {
      await ReminderService.instance.scheduleRemainingToday(times);
    }
  }
}

final reminderControllerProvider =
    AsyncNotifierProvider<ReminderController, List<ReminderTime>>(
        ReminderController.new);

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_time.dart';

/// Layanan notifikasi PENGINGAT belajar terjadwal.
///
/// Berbeda dari notifikasi foreground timer (flutter_foreground_task): ini
/// notifikasi lokal yang dijadwalkan di jam-jam yang diatur user untuk MENYURUH
/// mulai belajar.
///
/// KETERBATASAN PENTING (trade-off disepakati untuk skala tugas kuliah):
/// Keputusan "jadwalkan atau batalkan" diambil pada MOMEN TERTENTU — saat app
/// dibuka (HomeScreen load) atau saat sebuah sesi selesai disimpan — BUKAN
/// pengecekan real-time tepat pada jam notifikasi seharusnya tampil. Artinya:
/// jika user belajar lewat jalur yang tidak memicu reconcile, atau kondisi
/// berubah setelah app ditutup, notifikasi yang sudah terjadwal tetap tampil.
/// Untuk akurasi real-time dibutuhkan server push (FCM) / WorkManager periodik,
/// di luar lingkup fase ini.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'study_reminder_channel';
  static const _channelName = 'Pengingat Belajar';
  static const _channelDesc =
      'Notifikasi pengingat untuk mulai sesi belajar di jam yang kamu atur.';

  /// Payload yang dikirim agar tap notifikasi → buka Timer Setup.
  static const reminderPayload = 'open_timer_setup';

  /// Pesan motivasional (dipilih acak agar tidak monoton).
  static const _messages = [
    'Belum belajar hari ini? Yuk mulai sesi singkat sekarang 💪',
    'Luangkan 25 menit buat fokus. Sedikit progres tetap progres 🔥',
    'Yuk rawat ritme belajarmu — mulai satu sesi sekarang ✨',
  ];

  /// Dipanggil saat notifikasi ditap (di-set dari main untuk navigasi).
  void Function()? onSelectOpenTimer;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    // Small icon WAJIB drawable putih solid (bukan @mipmap/ic_launcher yang
    // adaptif) — kalau tidak, notifikasi terjadwal bisa gagal tampil diam-diam
    // di Android 12+. Lihat drawable/ic_stat_notification.xml.
    const androidInit = AndroidInitializationSettings('ic_stat_notification');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload == reminderPayload) onSelectOpenTimer?.call();
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Buat channel HIGH importance sejak awal (bukan default LOW) agar
    // notifikasi tampil di status bar / lock screen.
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    ));
    // Izin notifikasi (Android 13+) — aman bila sudah granted.
    await android?.requestNotificationsPermission();
    // Izin exact alarm (Android 12+). Dengan USE_EXACT_ALARM di manifest,
    // umumnya sudah granted; panggil tetap aman.
    await android?.requestExactAlarmsPermission();

    _initialized = true;
  }

  /// Apakah app diluncurkan dari keadaan TERMINATED karena tap notifikasi
  /// pengingat? (tap saat app hidup ditangani [onSelectOpenTimer].)
  Future<bool> launchedFromReminder() async {
    if (kIsWeb) return false;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload == reminderPayload;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
        ),
      );

  /// Jadwalkan ulang pengingat untuk SISA hari ini (jam yang belum lewat).
  /// Selalu batalkan dulu agar tidak ada jadwal dobel.
  Future<void> scheduleRemainingToday(List<ReminderTime> times) async {
    if (kIsWeb) return;
    await cancelAll(times);
    final now = tz.TZDateTime.now(tz.local);
    final rnd = Random();
    for (final t in times) {
      final scheduled = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, t.hour, t.minute);
      if (!scheduled.isAfter(now)) continue; // jamnya sudah lewat → lewati
      final msg = _messages[rnd.nextInt(_messages.length)];
      await _plugin.zonedSchedule(
        id: t.notificationId,
        title: 'Waktunya belajar 📚',
        body: msg,
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminderPayload,
        // Tanpa matchDateTimeComponents → sekali tembak untuk hari ini saja.
        // Reschedule harian ditangani saat app dibuka / sesi selesai.
      );
    }
  }

  /// Batalkan semua pengingat yang dikenal (mis. user sudah belajar hari ini).
  Future<void> cancelAll(List<ReminderTime> times) async {
    if (kIsWeb) return;
    for (final t in times) {
      await _plugin.cancel(id: t.notificationId);
    }
  }
}

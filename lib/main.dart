import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/reminders/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseConfig.initialize();

  // Inisialisasi layanan native NON-ESENSIAL (port foreground service,
  // timezone, notifikasi pengingat). Hanya relevan di platform native.
  //
  // FIX Fase 9: SELURUH blok dibungkus try/catch. Kegagalan di sini TIDAK BOLEH
  // mencegah app boot ke UI. Bug sebelumnya: di APK release, resource icon
  // notifikasi tidak ditemukan → ReminderService.init() melempar
  // PlatformException yang tidak tertangkap → main() berhenti sebelum runApp()
  // → app stuck di splash. Timer & fitur lain tetap jalan walau init ini gagal.
  if (!kIsWeb) {
    try {
      FlutterForegroundTask.initCommunicationPort();

      // Timezone untuk penjadwalan pengingat yang akurat (zonedSchedule).
      tzdata.initializeTimeZones();
      try {
        final tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
        tz.setLocalLocation(tz.getLocation(tzName));
      } catch (_) {
        // Gagal deteksi zona → biarkan default (UTC).
      }

      // Notifikasi pengingat belajar: tap → buka Timer Setup lewat router global.
      ReminderService.instance.onSelectOpenTimer =
          () => rootRouter?.push(AppRoutes.timerSetup);
      await ReminderService.instance.init();
    } catch (e, st) {
      // Jangan blok boot. Log saja (tidak ditelan diam-diam).
      debugPrint('Init layanan native gagal, dilewati: $e\n$st');
    }
  }

  runApp(
    const ProviderScope(
      child: SmartLearningApp(),
    ),
  );
}

class SmartLearningApp extends ConsumerWidget {
  const SmartLearningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

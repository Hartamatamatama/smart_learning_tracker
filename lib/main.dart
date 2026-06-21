import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseConfig.initialize();

  // Port komunikasi antara isolate UI dan foreground service timer.
  // Hanya relevan di platform native (bukan Web).
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
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

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

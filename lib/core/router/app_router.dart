import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/mood/screens/mood_journal_screen.dart';
import '../../features/timer/providers/timer_state.dart';
import '../../features/timer/screens/timer_run_screen.dart';
import '../../features/timer/screens/timer_setup_screen.dart';

// ---------------------------------------------------------------------------
// Route names (type-safe, pakai konstanta supaya tidak typo)
// ---------------------------------------------------------------------------

abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const timerSetup = '/timer-setup';
  static const timerRun = '/timer-run';
  static const moodJournal = '/mood-journal';
}

// ---------------------------------------------------------------------------
// Router provider
//
// Menggunakan ValueNotifier sebagai refreshListenable agar GoRouter
// otomatis mengevaluasi ulang redirect() setiap kali AppAuthState berubah.
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  // ValueNotifier yang "dipicu" setiap auth state berubah
  final authListenable = ValueNotifier<AppAuthState>(
    ref.read(authNotifierProvider),
  );

  ref.listen<AppAuthState>(authNotifierProvider, (_, next) {
    authListenable.value = next;
  });

  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authListenable,
    redirect: (BuildContext context, GoRouterState state) {
      return _redirect(authListenable.value, state.matchedLocation);
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.timerSetup,
        builder: (_, __) => const TimerSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.timerRun,
        builder: (_, __) => const TimerRunScreen(),
      ),
      GoRoute(
        path: AppRoutes.moodJournal,
        // Hanya valid jika dibuka dengan MoodNavRequest (lewat extra).
        // Jika diakses langsung tanpa data, kembalikan ke Home.
        redirect: (_, state) =>
            state.extra is MoodNavRequest ? null : AppRoutes.home,
        builder: (_, state) =>
            MoodJournalScreen(request: state.extra as MoodNavRequest),
      ),
    ],
  );
});

String? _redirect(AppAuthState authState, String location) {
  final isAuthScreen =
      location == AppRoutes.login || location == AppRoutes.register;

  final result = switch (authState) {
    // Sedang menentukan status auth → tahan di splash atau auth screen
    // (jangan unmount login/register agar dialog konfirmasi email bisa tampil)
    AuthInitial() || AuthLoading() =>
      (isAuthScreen || location == AppRoutes.splash) ? null : AppRoutes.splash,

    // Sudah login → jangan biarkan di auth screen atau splash
    AuthAuthenticated() =>
      (isAuthScreen || location == AppRoutes.splash) ? AppRoutes.home : null,

    // Belum login atau error → arahkan ke login kecuali sudah di auth screen
    AuthUnauthenticated() || AuthError() =>
      isAuthScreen ? null : AppRoutes.login,
  };

  return result;
}

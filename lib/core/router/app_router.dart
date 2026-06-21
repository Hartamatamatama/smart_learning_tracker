import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';

// ---------------------------------------------------------------------------
// Route names (type-safe, pakai konstanta supaya tidak typo)
// ---------------------------------------------------------------------------

abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
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

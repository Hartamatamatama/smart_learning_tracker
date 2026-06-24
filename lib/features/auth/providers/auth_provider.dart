import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../shared/models/user_profile.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class AppAuthState {
  const AppAuthState();
}

final class AuthInitial extends AppAuthState {
  const AuthInitial();
}

final class AuthLoading extends AppAuthState {
  const AuthLoading();
}

final class AuthAuthenticated extends AppAuthState {
  const AuthAuthenticated({required this.user, this.profile});
  final User user;
  final UserProfile? profile;
}

final class AuthUnauthenticated extends AppAuthState {
  const AuthUnauthenticated({this.message});
  final String? message;
}

final class AuthError extends AppAuthState {
  const AuthError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends Notifier<AppAuthState> {
  SupabaseClient get _client => SupabaseConfig.client;

  @override
  AppAuthState build() {
    final sub = _client.auth.onAuthStateChange.listen(_handleSupabaseAuthChange);
    ref.onDispose(sub.cancel);

    final user = _client.auth.currentUser;
    if (user != null) {
      Future.microtask(() => _loadAndSetProfile(user));
      return const AuthLoading();
    }
    return const AuthUnauthenticated();
  }

  void _handleSupabaseAuthChange(AuthState data) {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
      // initialSession: sesi dipulihkan dari storage saat app restart
      case AuthChangeEvent.initialSession:
        if (data.session?.user != null) {
          _loadAndSetProfile(data.session!.user);
        }
      case AuthChangeEvent.signedOut:
      // ignore: deprecated_member_use
      case AuthChangeEvent.userDeleted:
        state = const AuthUnauthenticated();
      default:
        break;
    }
  }

  Future<void> _loadAndSetProfile(User user) async {
    // Jangan override jika sudah authenticated dengan user yang sama (cegah loop)
    if (state is AuthAuthenticated && (state as AuthAuthenticated).user.id == user.id) {
      return;
    }
    state = const AuthLoading();
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      final profile = data != null ? UserProfile.fromJson(data) : null;
      state = AuthAuthenticated(user: user, profile: profile);
    } catch (_) {
      // Tetap authenticated meski profil gagal dimuat
      state = AuthAuthenticated(user: user);
    }
  }

  // ---------------------------------------------------------------------------
  // Auth actions
  // ---------------------------------------------------------------------------

  Future<void> signIn(String email, String password) async {
    if (state is AuthLoading) return;
    state = const AuthLoading();
    try {
      // FIX Bug 1: langsung handle response signInWithPassword, tidak hanya
      // mengandalkan onAuthStateChange stream yang bisa delay.
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        await _loadAndSetProfile(user);
      } else {
        state = const AuthUnauthenticated();
      }
    } on AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (_) {
      state = const AuthError('Tidak dapat terhubung. Periksa koneksi internet Anda.');
    }
  }

  /// Mengembalikan pesan sukses (butuh konfirmasi email) atau null jika langsung login.
  Future<String?> signUp(String email, String password, String fullName) async {
    if (state is AuthLoading) return null;
    state = const AuthLoading();
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      if (response.session != null && response.user != null) {
        // Email confirmation dinonaktifkan → langsung masuk
        await _loadAndSetProfile(response.user!);
        return null;
      } else {
        // Email confirmation aktif → user harus cek inbox
        state = const AuthUnauthenticated();
        return 'Akun berhasil dibuat! Cek inbox $email untuk konfirmasi sebelum login.';
      }
    } on AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
      return null;
    } catch (_) {
      state = const AuthError('Tidak dapat terhubung. Periksa koneksi internet Anda.');
      return null;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AuthUnauthenticated();
  }

  Future<void> signInWithGoogle() async {
    if (state is AuthLoading) return;
    state = const AuthLoading();
    try {
      // TODO: GOOGLE_SIGNIN_SETUP — lihat GOOGLE_SIGNIN_SETUP.md
      const bool isWeb = bool.fromEnvironment('dart.library.html');
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: isWeb ? null : 'com.skripsi.smartlearningtracker://login-callback/',
      );
      // State akan diperbarui via onAuthStateChange setelah OAuth selesai
    } on AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (_) {
      state = const AuthError('Google Sign-In gagal. Coba lagi.');
    }
  }

  String _mapAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials') || m.contains('wrong')) {
      return 'Email atau password salah.';
    }
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Email ini sudah terdaftar. Silakan login.';
    }
    if (m.contains('not confirmed') || m.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox Anda.';
    }
    if (m.contains('password') && m.contains('weak')) {
      return 'Password terlalu lemah. Gunakan minimal 8 karakter.';
    }
    // Termasuk error DNS/socket umum agar tidak menampilkan stack-trace ke user
    // (mis. di emulator dengan DNS bermasalah atau saat HP offline/WiFi captive).
    if (m.contains('network') ||
        m.contains('connection') ||
        m.contains('failed host lookup') ||
        m.contains('socketexception') ||
        m.contains('no address associated') ||
        m.contains('clientexception') ||
        m.contains('timeout') ||
        m.contains('unreachable')) {
      return 'Tidak dapat terhubung. Periksa koneksi internet Anda.';
    }
    return message;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authNotifierProvider = NotifierProvider<AuthNotifier, AppAuthState>(
  AuthNotifier.new,
);

final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return switch (authState) {
    AuthAuthenticated(:final profile) => profile,
    _ => null,
  };
});

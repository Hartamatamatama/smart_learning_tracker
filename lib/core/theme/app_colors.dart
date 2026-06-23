import 'package:flutter/material.dart';

/// Design tokens "Focus Ritual".
/// Aksen lime (fokus/aksi/performa) & coral (mood/emosi) konsisten di kedua mode.
class AppColors {
  AppColors._();

  // Aksen (sama di dark & light)
  static const lime = Color(0xFFC8FF4D); // aksi, progress, performa
  static const coral = Color(0xFFFF6B5B); // mood, emosi, jurnal

  // Teks di atas aksen terang → harus gelap
  static const onLime = Color(0xFF101307);
  static const onCoral = Color(0xFF1A0B09);

  // Semantik
  static const success = Color(0xFF5FD98A);
  static const warning = Color(0xFFFFB84D);
  static const error = Color(0xFFFF5C5C);

  // ---- DARK ----
  static const dBg = Color(0xFF0E0F11);
  static const dSurface = Color(0xFF1A1C1F);
  static const dSurfaceElevated = Color(0xFF22252A);
  static const dTextPrimary = Color(0xFFF5F5F0);
  static const dTextMuted = Color(0xFF8A8D91);
  static const dBorder = Color(0xFF2A2D31);

  // ---- LIGHT ----
  static const lBg = Color(0xFFF7F7F4);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceElevated = Color(0xFFFFFFFF);
  static const lTextPrimary = Color(0xFF16181A);
  static const lTextMuted = Color(0xFF6B6F73);
  static const lBorder = Color(0xFFE2E2DC);
  // Varian lime sedikit lebih gelap untuk teks/ikon di atas bg terang.
  static const limeDeep = Color(0xFF7FA800);
}

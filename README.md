# Smart Learning Tracker

Aplikasi **self-regulated learning** (pelacak belajar) berbasis Flutter: gabungkan
timer fokus, ambient sound, jurnal mood, dan **analisis AI** dalam satu ekosistem
untuk membantu pelajar membangun kebiasaan belajar yang lebih sadar dan terukur.

Dikembangkan sebagai proyek skripsi. Konsep visual **"Focus Ritual"** (mode gelap,
aksen lime) diterapkan di seluruh aplikasi.

---

## ✨ Fitur Utama

- **Autentikasi** — Email/Password (Supabase Auth) + Google Sign-In.
- **Timer Belajar** — mode Pomodoro (hitung mundur + istirahat otomatis) dan
  Stopwatch. Berjalan akurat di latar belakang via *foreground service*, dengan
  notifikasi persisten + tombol Jeda/Stop.
- **Ambient Sound** — suara latar opsional (hujan, hutan, kafe, dll) saat sesi.
- **Jurnal Mood** — pencatatan mood multi-parameter (mood umum, fokus, kelelahan,
  motivasi) setiap selesai sesi.
- **Riwayat & Analitik** — daftar sesi dengan filter & pagination, ringkasan grafik.
- **Analyze Ourself (Laporan AI)** — analisis performa belajar via OpenRouter,
  lengkap dengan grafik, dan **ekspor ke PDF** (teks + grafik) untuk dibagikan.
- **Pengingat Belajar** — notifikasi terjadwal di jam yang diatur user; otomatis
  dibatalkan bila sudah belajar hari itu.
- **Tema Dark/Light** dengan persistensi preferensi.

---

## 🖼️ Screenshots

> Belum disertakan di repo. Untuk menambahkan: letakkan file gambar di
> `docs/screenshots/` lalu tautkan di bagian ini (mis. Home, Timer, Laporan AI,
> Pengaturan). Sengaja tidak diisi placeholder gambar yang tidak ada.

---

## 🧱 Tech Stack

| Lapisan | Teknologi |
|---|---|
| Framework | **Flutter** (Android + Web dari satu codebase) |
| State management | **Riverpod** |
| Backend / Auth / DB | **Supabase** (PostgreSQL + RLS) |
| AI | **OpenRouter API** (model gratis, satu arah) |
| Routing | go_router |
| Lainnya | just_audio, fl_chart, dio, flutter_foreground_task, flutter_local_notifications, pdf/printing, google_fonts |

---

## 🚀 Setup Development (ringkas)

Panduan lengkap ada di **[SETUP.md](SETUP.md)**. Ringkasnya:

1. **Prasyarat:** Flutter SDK ≥ 3.35, akun Supabase (free), akun OpenRouter (free).
2. **Environment:** salin `.env.example` → `.env`, isi `SUPABASE_URL`,
   `SUPABASE_ANON_KEY`, `OPENROUTER_API_KEY`. (`.env` **tidak** di-commit.)
3. **Database:** jalankan file SQL di `supabase/migrations/` lewat Supabase SQL Editor
   (berurutan).
4. **Install & jalankan:**
   ```bash
   flutter pub get
   flutter run
   ```

---

## 📦 Build APK Release

Butuh keystore signing (lihat dok. resmi Flutter *Android app signing*). Konfigurasi
`android/key.properties` (referensi keystore di luar repo; **tidak** di-commit), lalu:

```bash
flutter build apk --release
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

APK siap-install tersedia di halaman **[Releases](../../releases)** repo ini.

---

## 🔔 Catatan Notifikasi (Android)

Sebagian HP (mis. Xiaomi/MIUI, Oppo, Vivo, **Infinix/Transsion**) punya manajemen
baterai/hibernasi agresif yang bisa membuat notifikasi terjadwal tidak muncul di
latar belakang. Langkah pengaturan manual per-merk ada di
**[TROUBLESHOOTING_NOTIFICATIONS.md](TROUBLESHOOTING_NOTIFICATIONS.md)**.

---

## 📁 Struktur Singkat

```
lib/
  core/            # router, theme, constants, utils
  config/          # Supabase config
  features/        # auth, timer, ambient_sound, mood, history,
                   # analytics, ai_report, reminders, home
  shared/          # model & widget bersama
supabase/migrations/  # skema database (dijalankan manual)
```

---

Dibuat untuk keperluan skripsi. Lisensi: penggunaan pribadi/akademik.

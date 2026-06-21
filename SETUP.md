# Smart Learning Tracker — Panduan Setup

## 1. Prasyarat

- Flutter SDK >= 3.35.x
- Akun [Supabase](https://supabase.com) (free tier cukup)
- Akun [OpenRouter](https://openrouter.ai) (gratis, daftar untuk dapat API key)

---

## 2. Mengisi File `.env`

Salin `.env.example` menjadi `.env` (sudah ada), lalu isi nilainya:

```
SUPABASE_URL=https://xxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
OPENROUTER_API_KEY=sk-or-v1-...
```

**Cara dapat nilai tersebut:**

| Variabel | Di mana menemukannya |
|---|---|
| `SUPABASE_URL` | Dashboard Supabase → Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Dashboard Supabase → Settings → API → anon public |
| `OPENROUTER_API_KEY` | [openrouter.ai/keys](https://openrouter.ai/keys) |

> **PENTING:** Jangan pernah commit file `.env`. File ini sudah masuk `.gitignore`.

---

## 3. Menjalankan Migration SQL ke Supabase

1. Buka [app.supabase.com](https://app.supabase.com) → pilih project Anda
2. Masuk ke menu **SQL Editor**
3. Klik **New Query**
4. Buka file `supabase/migrations/0001_initial_schema.sql` di text editor
5. Copy seluruh isinya, paste ke SQL Editor, lalu klik **Run**
6. Jika berhasil, cek tabel di menu **Table Editor** — seharusnya muncul 9 tabel baru

---

## 4. Menjalankan Aplikasi

```bash
# Install dependencies
flutter pub get

# Run di Android (pastikan emulator/device sudah aktif)
flutter run

# Run di browser (Chrome)
flutter run -d chrome

# Run di device tertentu
flutter run -d <device-id>   # lihat device: flutter devices
```

---

## 5. Struktur Folder

```
smart_learning_tracker/
├── .env                    ← environment variables (JANGAN COMMIT)
├── .env.example            ← template .env (aman di-commit)
├── SETUP.md                ← file ini
├── supabase/
│   └── migrations/
│       └── 0001_initial_schema.sql   ← skema database
├── assets/
│   └── sounds/             ← file audio ambient (mp3/ogg)
└── lib/
    ├── main.dart            ← entry point, inisialisasi Supabase + Riverpod
    ├── config/
    │   ├── env.dart         ← helper baca variabel .env dengan aman
    │   └── supabase_config.dart  ← inisialisasi & akses Supabase client
    ├── core/
    │   ├── constants/
    │   │   └── app_constants.dart   ← konstanta global (nama app, URL, dll)
    │   ├── theme/
    │   │   └── app_theme.dart       ← ThemeData light & dark
    │   └── utils/
    │       └── duration_formatter.dart  ← utilitas format durasi
    ├── features/
    │   ├── auth/            ← login, register, logout
    │   │   ├── screens/
    │   │   ├── widgets/
    │   │   └── providers/
    │   ├── timer/           ← countdown timer sesi belajar
    │   │   ├── screens/
    │   │   ├── widgets/
    │   │   └── providers/
    │   ├── ambient_sound/   ← pemutar suara latar
    │   │   ├── screens/
    │   │   ├── widgets/
    │   │   └── providers/
    │   ├── journal/         ← form pengisian jurnal mood pasca-sesi
    │   │   ├── screens/
    │   │   ├── widgets/
    │   │   └── providers/
    │   ├── history/         ← riwayat semua sesi belajar
    │   │   ├── screens/
    │   │   ├── widgets/
    │   │   └── providers/
    │   └── ai_report/       ← fitur "Analyze Ourself" (laporan AI)
    │       ├── screens/
    │       ├── widgets/
    │       └── providers/
    └── shared/
        ├── widgets/         ← komponen UI reusable lintas fitur
        └── models/          ← model data (PODO) yang dipakai di banyak fitur
```

---

## 6. Keputusan Teknis

| Topik | Pilihan | Alasan |
|---|---|---|
| State management | **Riverpod** | Compile-safe, tidak butuh BuildContext, lebih scalable untuk fitur async |
| Audio | **just_audio** | Stabil untuk looping + playback di Android & Web |
| HTTP client | **dio** | Interceptor built-in untuk inject API key ke header OpenRouter |
| Skema DB | 5 master + 4 transaksi | Cukup untuk fitur MVP, mudah diperluas |

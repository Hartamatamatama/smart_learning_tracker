# Panduan Setup Google Sign-In

Google Sign-In menggunakan OAuth 2.0 via Supabase. Setup ini membutuhkan aksi
manual di **Google Cloud Console** dan **Supabase Dashboard**.
Ikuti langkah berikut secara berurutan.

---

## Ringkasan Alur

```
App (Flutter)
  → Supabase OAuth Endpoint
    → Google OAuth Consent Screen
      → Kembali ke Supabase callback
        → Redirect ke app via deep link (Android)
```

---

## Bagian 1 — Google Cloud Console

### 1.1 Buat Project (jika belum ada)

1. Buka [console.cloud.google.com](https://console.cloud.google.com)
2. Klik dropdown project di atas → **New Project**
3. Beri nama: `Smart Learning Tracker`
4. Klik **Create**

### 1.2 Aktifkan Google+ API / People API

1. Di menu kiri → **APIs & Services → Library**
2. Cari "Google Identity" atau "People API"
3. Klik **Enable**

### 1.3 Buat OAuth Consent Screen

1. **APIs & Services → OAuth consent screen**
2. Pilih **External** → **Create**
3. Isi:
   - App name: `Smart Learning Tracker`
   - User support email: email Anda
   - Developer contact email: email Anda
4. Klik **Save and Continue** (scopes dan test users bisa diisi belakangan)
5. Tambahkan email Anda sebagai **Test User** di langkah "Test users"

### 1.4 Buat OAuth Client ID — Tipe Web

> Digunakan oleh Supabase sebagai perantara OAuth. BUKAN untuk app langsung.

1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Application type: **Web application**
3. Name: `Supabase OAuth Proxy`
4. **Authorized redirect URIs** — tambahkan:
   ```
   https://xvkzirdexooolczcgdeq.supabase.co/auth/v1/callback
   ```
   *(Ganti dengan Project URL Supabase Anda — sudah sesuai jika pakai URL di .env)*
5. Klik **Create**
6. Catat **Client ID** dan **Client Secret** → akan dimasukkan ke Supabase

### 1.5 Dapatkan SHA-1 Fingerprint (untuk Android)

> **PENTING:** APK debug (`flutter run`) dan APK release (`flutter build apk
> --release`) menggunakan **keystore yang BERBEDA**, sehingga **SHA-1 berbeda**.
> Google OAuth menolak request dari APK yang SHA-1-nya belum terdaftar.
> **DUA SHA-1 wajib didaftarkan** di Android OAuth Client (debug + release),
> kalau tidak Google Sign-In akan gagal diam-diam di salah satu build.

#### SHA-1 debug (untuk `flutter run` / install APK debug)

```powershell
keytool -list -v `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -alias androiddebugkey `
  -storepass android `
  -keypass android
```

#### SHA-1 release (untuk APK rilis yang ditandatangani keystore Fase 9)

```powershell
keytool -list -v `
  -keystore "C:\Users\THIN\Documents\Tugas Kuliah\Project 3\keystore\slt-release.jks" `
  -alias slt `
  -storepass slt_skripsi_2026
```

Cari baris `SHA1:` pada masing-masing output. Contoh format:
```
SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

### 1.6 Buat / Edit OAuth Client ID — Tipe Android

1. **APIs & Services → Credentials**
2. Klik OAuth Client ID Android yang sudah ada (atau **Create Credentials →
   OAuth client ID → Android** bila belum ada).
3. Package name: `com.skripsi.smart_learning_tracker`
4. Di bagian **SHA-1 certificate fingerprints**, klik tombol untuk menambah
   baris baru → **DAFTARKAN KEDUA SHA-1** (debug DAN release). Satu OAuth
   Client Android boleh punya banyak SHA-1 — tidak perlu bikin dua client
   terpisah.
5. Klik **Save**.
6. Tunggu beberapa menit (kadang sampai ~5 menit) sampai perubahan SHA-1
   ter-propagate ke server Google sebelum testing ulang.
7. Client ID Android **tidak memerlukan Client Secret** — cukup didaftarkan.

---

## Bagian 2 — Supabase Dashboard

### 2.1 Aktifkan Provider Google

1. Buka [app.supabase.com](https://app.supabase.com) → pilih project Anda
2. **Authentication → Providers**
3. Klik **Google** → toggle **Enable**
4. Isi:
   - **Client ID**: Client ID dari langkah 1.4 (Web application)
   - **Client Secret**: Client Secret dari langkah 1.4
5. Klik **Save**

### 2.2 Tambahkan Redirect URL

1. **Authentication → URL Configuration**
2. Di bagian **Redirect URLs**, klik **Add URL**
3. Tambahkan URL berikut:
   ```
   com.skripsi.smartlearningtracker://login-callback/
   ```
4. Untuk development web (jika test di browser):
   ```
   http://localhost:PORT
   ```
   *(ganti PORT dengan port yang dipakai `flutter run -d chrome`, biasanya 8080 atau acak)*
5. Klik **Save**

---

## Bagian 3 — Verifikasi Kode (sudah diimplementasi)

Bagian ini hanya informasi — tidak perlu Anda ubah, sudah ada di kode.

### AndroidManifest.xml

File `android/app/src/main/AndroidManifest.xml` sudah memiliki intent filter:
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="com.skripsi.smartlearningtracker"
        android:host="login-callback" />
</intent-filter>
```
Ini menangkap deep link dari browser setelah OAuth selesai.

### supabase_config.dart

PKCE flow sudah diaktifkan — lebih aman dari Implicit flow untuk mobile.

### auth_provider.dart

`signInWithGoogle()` memanggil:
```dart
await _client.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'com.skripsi.smartlearningtracker://login-callback/', // Android
);
```

---

## Bagian 4 — Test Google Sign-In

Setelah semua setup selesai:

1. Jalankan app di Android emulator/device: `flutter run`
2. Tap **Masuk dengan Google**
3. Browser (Chrome Custom Tabs) akan terbuka → pilih akun Google
4. Setelah konfirmasi, app akan otomatis membuka kembali dan user masuk ke HomeScreen
5. Cek tabel `profiles` di Supabase — baris baru harus muncul otomatis (via trigger)

### Catatan untuk Web

- Di browser, OAuth menggunakan popup atau redirect tab baru
- Redirect URL harus menggunakan URL yang tepat sesuai port `flutter run -d chrome`
- Saat production deploy, ganti redirect URL ke domain produksi

---

## Troubleshooting

| Masalah | Kemungkinan Penyebab |
|---|---|
| `redirect_uri_mismatch` | Redirect URI di Google Cloud tidak cocok dengan Supabase callback |
| Browser buka tapi app tidak kembali | Intent filter belum terdaftar atau scheme salah |
| `Error 400: admin_policy_enforced` | Akun Google belum ditambahkan sebagai test user di OAuth consent screen |
| `Invalid client` | Client ID/Secret salah di Supabase |
| SHA-1 error | Gunakan SHA-1 dari debug.keystore yang benar |

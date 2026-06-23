# Troubleshooting Notifikasi (Timer & Pengingat Belajar)

Dokumen ini menjelaskan kenapa notifikasi bisa tidak muncul di sebagian HP, mana
yang sudah ditangani dari KODE, dan mana yang HARUS diatur MANUAL di Settings HP
(karena tidak bisa diminta lewat API Android).

---

## 1. Yang sudah diperbaiki dari kode (Fase 8)

| Masalah | Penyebab | Fix |
|---|---|---|
| Notifikasi timer tidak muncul di status bar / lock screen | Notification channel dibuat dengan importance **LOW** (default `flutter_foreground_task`) | Channel di-set **HIGH** + `priority HIGH` + `visibility PUBLIC`. **Channel id di-bump ke `study_timer_channel_v2`** karena importance channel bersifat *immutable* setelah dibuat |
| Service bisa dibekukan Doze standar Android | Kode belum minta pengecualian battery optimization | Tambah `requestIgnoreBatteryOptimization()` di alur start sesi |
| Izin `POST_NOTIFICATIONS` (Android 13+) | — | Sudah diminta sebelum sesi pertama, plus dialog penjelasan kontekstual |

> **PENTING (untuk tester):** karena channel id berubah, perubahan importance
> hanya berlaku setelah **uninstall + install ulang** app (atau Clear data).
> Update biasa tidak cukup kalau channel lama masih ada — Android tidak akan
> menaikkan importance channel yang sudah terlanjur dibuat.

---

## 2. Yang HARUS diatur manual (tidak bisa dari kode)

Beberapa merk HP punya lapisan manajemen baterai DI LUAR API Android standar.
Pengaturan ini **tidak bisa** diminta aplikasi secara programatik — pengguna
wajib mengaktifkannya sendiri. HP uji di proyek ini: **Infinix (Transsion / XOS)**.

> **TEMUAN NYATA saat self-test Fase 8 (Infinix X6880, Android 15):**
> Notifikasi foreground TIMER (Bagian A) sudah TAMPIL dengan benar di status bar
> & lock screen setelah fix importance HIGH. TAPI notifikasi PENGINGAT TERJADWAL
> tidak ikut muncul saat dijadwalkan, **walaupun alarm-nya benar-benar terpicu
> tepat waktu** (terbukti via `dumpsys alarm`: `RTC_WAKEUP` ke
> `ScheduledNotificationReceiver` plugin, jam persis). Penyebabnya terlihat jelas
> di logcat: framework **"Hiber" / "Griffin"** milik Transsion **membekukan
> proses app** (`Hiber/stateManager: freeze uid:...`) dan mem-**proxy/menunda
> alarm**-nya (`Hiber/hiber: proxy alarm`). Saat alarm terpicu, app sempat
> di-unfreeze "reason:alarm" dan broadcast sampai ke receiver, tapi Hiber
> langsung membekukan-mencairkan proses berulang (`fastFreeze`/`fastUnFreeze`)
> sehingga proses post-notifikasi tidak tuntas. Ini **murni perilaku OEM** —
> tidak bisa diperbaiki dari kode (pengecualian battery optimization standar
> Android sudah diminta & diberikan, tapi tidak menjangkau Hiber). **Solusinya
> wajib via pengaturan manual di bawah** (Autostart + jangan-bekukan + Power
> Marathon). Setelah pengaturan ini aktif, pengingat terjadwal akan muncul.

### Infinix / Tecno / itel (Transsion — XOS / HiOS)

Aktifkan SEMUA ini untuk Smart Learning Tracker:

1. **Autostart / Auto-launch**
   `Settings → Apps → App management → Smart Learning Tracker → Auto-launch` → **ON**
   (atau via app **"Phone Master" / "Power Marathon"** bawaan Transsion).
2. **Kecualikan dari Power Marathon / Battery saver**
   `Phone Master → Power Marathon (Penghemat daya) → App-app yang dilindungi`
   → tambahkan / centang **Smart Learning Tracker**. Atau:
   `Settings → Battery → Power Marathon → Protected apps`.
3. **Jangan "bekukan" app saat layar mati**
   `Settings → Battery → Background freeze / App freeze` → keluarkan app dari
   daftar yang dibekukan (set ke **No restrictions / Tidak dibatasi**).
4. **Kunci app di Recent / Multitask**
   Buka Recent apps (kotak/swipe up), tarik kartu app ke bawah atau tap ikon
   gembok → **kunci**, supaya tidak ter-"clean" otomatis.
5. **Izin notifikasi & lock screen**
   `Settings → Notifications → Smart Learning Tracker` → izinkan semua, dan
   pastikan **"Lock screen notifications"** = Tampilkan.
   Khusus channel **"Timer Belajar"** & **"Pengingat Belajar"**: pastikan
   importance **High / Urgent** (bukan Silent).

### Catatan untuk merk lain (jika app diuji di HP lain)

- **Xiaomi/Redmi/POCO (MIUI/HyperOS):** Settings → Apps → izin "Autostart" ON;
  Battery saver app = **No restrictions**; di Recent, kunci app.
- **Oppo/Realme/OnePlus (ColorOS):** "Allow auto launch" ON; Battery →
  "Allow background activity" / "Don't optimize".
- **Vivo/iQOO (Funtouch/OriginOS):** "Auto-start" ON; "High background power
  consumption" → izinkan.
- **Samsung (One UI):** Settings → Battery → "Unrestricted" untuk app; matikan
  "Put app to sleep" untuk app ini di "Sleeping apps".
- **Huawei (EMUI):** "App launch" → Manage manually → semua ON.

---

## 3. Cek cepat lewat ADB (untuk developer)

```bash
# importance channel (harus 4 = HIGH untuk study_timer_channel_v2)
adb shell dumpsys notification | grep -A2 study_timer_channel

# apakah app di-whitelist dari Doze
adb shell dumpsys deviceidle whitelist | grep skripsi

# status izin POST_NOTIFICATIONS
adb shell dumpsys package com.skripsi.smart_learning_tracker | grep POST_NOTIFICATIONS
```

Kalau importance masih `mImportance=2` setelah update kode → channel lama masih
ada → **uninstall + install ulang**.

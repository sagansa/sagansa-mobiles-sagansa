# Panduan Aktivasi Firebase Cloud Messaging (Push Notifikasi) — Sagansa Mobile

> **Status: SUDAH DIAKTIFKAN (2026-08-18).** Kedua file konfigurasi sudah
> tersedia, plugin Gradle sudah aktif, `GoogleService-Info.plist` sudah
> ter-register di Xcode, dan entitlements Push Notifications +
> `UIBackgroundModes: remote-notification` sudah terpasang. Dokumen di bawah
> tetap berguna sebagai referensi (verifikasi ulang, device baru, atau rollback).

Kode FCM (Flutter + backend) sudah lengkap tapi **dorman** sampai dua file
konfigurasi Firebase ditaruh di repo:

| File | Lokasi | Fungsi |
|------|--------|--------|
| `google-services.json` | `mobiles/sagansa/android/app/` | Android: menghubungkan app ke project Firebase |
| `GoogleService-Info.plist` | `mobiles/sagansa/ios/Runner/` | iOS: menghubungkan app ke project Firebase |

Tanpa kedua file itu, plugin Gradle sengaja dikomentari dan `Firebase.initializeApp()`
di-bungkus `try/catch` — aplikasi tetap jalan normal, hanya push yang tidak aktif.
Setelah file tersedia, ikuti langkah aktivasi di bawah, lalu test end-to-end.

---

## 0. Prasyarat

- [ ] Project di [Firebase Console](https://console.firebase.google.com/) sudah dibuat
- [ ] (iOS saja) Akun **Apple Developer Program** ($99/tahun) — wajib untuk Push Notifications
- [ ] Backend sudah punya service account (lihat Langkah 5)

---

## 1. Android — download & taruh `google-services.json`

1. Buka **Firebase Console** → project yang dipakai → **Project settings** (ikon ⚙) → tab **Your apps**.
2. Klik **Add app** → pilih **Android**.
3. **Android package name** diisi `id.sagansa.app` (sama persis dengan
   `applicationId` di `android/app/build.gradle`).
4. Klik **Register app** → unduh **`google-services.json`**.
5. Taruh file di **`mobiles/sagansa/android/app/google-services.json`**.
6. (Opsional) App nickname & signing certificate SHA-1 bisa dikosongkan untuk
   tahap awal — push tetap berfungsi.

**Aktifkan plugin Gradle** (tidak boleh di-uncomment sebelum file ada — build
Android akan gagal tanpa `google-services.json`):

- `android/settings.gradle` baris **29** — uncomment:
  ```gradle
  id "com.google.gms.google-services" version "4.4.2" apply false
  ```
- `android/app/build.gradle` baris **7** — uncomment:
  ```gradle
  id "com.google.gms.google-services"
  ```
- `android/app/build.gradle` baris **110–111** — uncomment:
  ```gradle
  implementation platform('com.google.firebase:firebase-bom:33.4.0')
  implementation 'com.google.firebase:firebase-messaging'
  ```

---

## 2. iOS — download & taruh `GoogleService-Info.plist`

1. Di **Firebase Console** → **Project settings** → **Add app** → pilih **iOS**.
2. **iOS bundle ID** diisi `id.sagansa.app` (sama persis dengan
   `PRODUCT_BUNDLE_IDENTIFIER` di `ios/Runner.xcodeproj/project.pbxproj`).
3. Klik **Register app** → unduh **`GoogleService-Info.plist`**.
4. Taruh file di **`mobiles/sagansa/ios/Runner/GoogleService-Info.plist`**.

**Registrasi plist ke target Runner di Xcode:**

1. Buka `mobiles/sagansa/ios/Runner.xcworkspace` di Xcode (wajib `.xcworkspace`,
   bukan `.xcodeproj`, karena memakai CocoaPods).
2. Di navigator kiri, pilih **Runner** (target) → tab **Build Phases**.
3. Buka **Copy Bundle Resources** → klik **+** → pilih `GoogleService-Info.plist`.
   Pastikan *target* yang dicentang hanya **Runner** (bukan RunnerTests).

**Capability Push Notifications & Background Modes:**

1. Di Xcode: pilih **Runner** target → tab **Signing & Capabilities**.
2. Klik **+ Capability** → tambahkan **Push Notifications**.
3. Klik **+ Capability** → tambahkan **Background Modes** → centang
   **Remote notifications**.
4. (Tanpa capability ini push iOS tidak akan tampil / tidak membangunkan app.)

**APNs Auth Key** (butuh akun Apple Developer):

1. Buka [Apple Developer](https://developer.apple.com/account/) → **Certificates,
   Identifiers & Profiles** → **Keys** → **+**.
2. Centang **APNs (Apple Push Notification service)** → **Continue**.
3. Simpan **Key ID** (10 karakter) & download file `.p8` (sekali unduh saja —
   simpan aman; tidak bisa diunduh ulang).
4. Di **Firebase Console** → **Project settings** → tab **Cloud Messaging** →
   bagian **iOS app configuration** → **APNs authentication key** → klik **Upload**:
   - **Key ID** = Key ID dari langkah 3
   - **Team ID** = 10 karakter dari halaman Membership akun Apple Developer
   - **Key file** = file `.p8`
5. Setelah upload, status berubah "Push notifications successfully configured".

---

## 3. Verifikasi kredensial backend (`services/api`)

Backend memakai `kreait/laravel-firebase` (admin SDK). Kredensial dari **service
account** Firebase:

1. **Firebase Console** → **Project settings** → tab **Service accounts** →
   **Generate new private key** → simpan file JSON (contoh `firebase-credentials.json`).
2. Letakkan file di luar repo publik (jangan di-commit), misal `services/api/storage/app/firebase/`.
3. Isi env di `services/api/.env`:
   ```
   FIREBASE_CREDENTIALS=/absolute/path/ke/firebase-credentials.json
   ```
   (Bisa juga pakai `GOOGLE_APPLICATION_CREDENTIALS` — `config/firebase.php:53`
   membaca keduanya; yang kosong akan fallback ke yang lain.)
4. Pastikan project ID di file service account cocok dengan project Firebase yang
   berisi app Android/iOS di atas.
5. Cek tidak ada error di log backend saat pengiriman push (`storage/logs/laravel.log`).

---

## 4. Aktifkan FCM di aplikasi (kode sudah aktif-otomatis)

Setelah file konfigurasi & plugin Gradle aktif, **tidak ada perubahan kode manual**
— mekanisme berikut sudah berjalan otomatis saat app dijalankan:

- `main.dart` memanggil `LocationTrackingService.instance.initialize()` → jika
  Firebase terdeteksi, background handler & foreground listener FCM terpasang.
- `LocationTrackingService.onLogin()` mendaftarkan FCM token device ke
  `POST /device-tokens`.
- Permission notifikasi (`alert/badge/sound = true`) diminta saat login.
- Foreground handler menampilkan notifikasi lokal + memanggil
  `NotificationProvider.onNotificationReceived()` → badge bell & daftar
  notifikasi ter-refresh **live**.
- Background handler menampilkan notifikasi lokal untuk semua tipe non-silent
  (`title`/`body` ada), termasuk tipe generik dari `NotificationDispatcher`.

> Saat **login**, token device harus ter-registrasi ulang. Gunakan akun yang
> sesuai dengan role penerima notifikasi (mis. `admin`/`super_admin` untuk
> `invoice_transfer_created`).

---

## 5. Tes end-to-end

**Cek token terdaftar:**
1. Login di app → cek tabel `device_tokens` di DB backend ada row untuk user tsb.
2. (Android) `adb logcat | grep -i fcm` — pastikan ada log sukses registrasi.

**Kirim test push (backend / console):**
1. Pakai Firebase Console → **Cloud Messaging** → **Create your first campaign**
   (atau kirim langsung via `FcmService` dari `php artisan tinker`):
   ```php
   $user = \App\Models\User::find(1);
   app(\App\Services\FcmService::class)->sendToUser($user->id, [
       'type' => 'invoice_transfer_created',
       'title' => 'Invoice Transfer Baru',
       'body' => 'Ada invoice transfer menunggu pembayaran.',
       'invoice_id' => '42',
   ]);
   ```
2. **Foreground**: app terbuka → notifikasi lokal muncul (heads-up) → badge bell
   & daftar notifikasi ter-refresh otomatis.
3. **Background/terminated**: app di-minimize/ditutup → push tetap tampil di
   tray notifikasi; tap → deep-link ke halaman detail.

**Catatan tipe payload:**
- `location_request` = silent (tidak menampilkan notifikasi; langsung kirim GPS).
- Tipe lain dengan `title`/`body` → ditampilkan sebagai notifikasi lokal.
- Android emulator tanpa Google Play Services tidak bisa menerima FCM — pakai
  device fisik atau emulator dengan Play Services.

---

## 6. Rollback / menonaktifkan FCM

Untuk mematikan push sementara (mis. sebelum rilis publik):

1. Komentari kembali plugin Gradle (`settings.gradle:29`, `app/build.gradle:7,110–111`).
2. Hapus/rename `google-services.json` & `GoogleService-Info.plist`.
3. Hapus `FIREBASE_CREDENTIALS` dari `.env` backend.
   App tetap berjalan normal (blok Firebase di-`try/catch`).
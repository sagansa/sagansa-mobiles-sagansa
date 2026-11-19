# Audit Kebijakan Google Play — Sagansa

Dokumen ini memetakan permission & data yang dikumpulkan Sagansa terhadap
[Google Play Developer Program Policies](https://play.google.com/about/developer-content-policy/),
untuk meminimalkan risiko penolakan saat submit.

> **Status rilis publik pertama:** permission & fitur paling sensitif (background
> location, foreground service, FCM, AD_ID) sengaja **dilepas** dari rilis awal
> agar lolos review cepat. Modul lokasi karyawan on-demand akan diaktifkan di
> rilis berikutnya dengan prominent disclosure yang sesuai.

---

## 1. Permission yang Dideklarasikan (final)

| Permission | Use case | Risiko kebijakan |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Check-in/check-out presensi karyawan (foreground, saat app terbuka) | **Sedang** — butuh prominent disclosure standar |
| `ACCESS_COARSE_LOCATION` | Fallback lokasi kasar untuk presensi | **Sedang** — sama dengan FINE |
| `POST_NOTIFICATIONS` | Notifikasi lokal (Android 13+) | Rendah |
| `INTERNET` | Komunikasi API backend | Rendah |
| `CAMERA` | Foto struk/bukti pembayaran, pemeriksaan aset, bukti pengiriman | **Sedang** — butuh justifikasi di Data Safety |

### Permission yang sengaja TIDAK dideklaskan di rilis awal

| Permission | Alasan dilepas | Kapan aktifkan kembali |
|---|---|---|
| `ACCESS_BACKGROUND_LOCATION` | Kategori paling ketat di Play. Butuh prominent disclosure kompleks + manual review. | Saat modul "lokasi on-demand karyawan" dirilis |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_LOCATION` | Berpasangan dengan background location. | Saat modul lokasi karyawan |

> **Catatan (jebakan manifest merger):** plugin `geolocator` mendeklarasikan
> `FOREGROUND_SERVICE_LOCATION` + `GeolocatorLocationService` di manifest
> library-nya, yang otomatis ter-merge ke AAB final walau app tidak
> menjalankannya — Play Console tetap mewajibkan deklarasi FGS + video demo
> karena mendeteksi permission di manifest hasil merge. Keduanya dilepas via
> `tools:node="remove"` di `android/app/src/main/AndroidManifest.xml`.
| `com.google.android.gms.permission.AD_ID` | **Tidak ada SDK iklan** di app. Deklarasi tanpa penggunaan = auto-reject/flag. | Hanya jika integrasi SDK iklan (tidak direncanakan) |

---

## 2. Data Safety Form (wajib diisi di Play Console)

Play Console mewajibkan deklarasi data yang dikumpulkan app. Berikut mapping
untuk Sagansa berdasarkan kode & permission yang aktif:

| Data type | Category | Purpose | Processed (ephemeral) | Shared | Required | Optional |
|---|---|---|---|---|---|---|
| **Lokasi tepat** (lat/long saat check-in) | Location | App functionality (absensi) | Tidak | Tidak (hanya ke backend Sagansa) | Wajib untuk fitur presensi | — |
| **Foto** (kamera: struk, aset, delivery) | Photos and videos | App functionality | Tidak | Tidak | — | Opsional (user bisa skip) |
| **Email / ID user** | Personal info | Account management | Tidak | Tidak | Wajib (login) | — |
| **ID toko/bisnis** | Financial info (business) | App functionality | Tidak | Tidak | Wajib | — |
| **Token sesi** | App activity | Account management | Tidak | Tidak | Wajib | — |
| **Data transaksi** (penjualan, stok) | Financial info | App functionality | Tidak | Tidak | Wajib | — |

### Pertanyaan Data Safety Form — jawaban:

- **Apakah app mengenkripsi data saat transmisi?** Ya (HTTPS via `network_security_config.xml`, cleartext diblok kecuali printer lokal).
- **Apakah user bisa minta hapus data?** Ya (hubungi admin Sagansa — data tersinkron ke backend). *Catatan: sediakan endpoint/proses deletion request untuk compliance.*
- **Apakah data dibagi ke pihak ketiga?** Tidak.

---

## 3. Foreground Location Permission — Prominent Disclosure

Karena app memakai `ACCESS_FINE_LOCATION` saat app terbuka (bukan background),
Play **tidak mewajibkan** prominent disclosure kompleks. Namun, ada dialog
permission standar Android yang harus disertai justifikasi jelas.

### Rekomendasi UI sebelum `Geolocator.requestPermission()`:

> **"Sagansa memerlukan akses lokasi Anda"**
> Untuk mencatat kehadiran (check-in/check-out), Sagansa perlu mengetahui lokasi
> Anda. Lokasi dikirim ke server Sagansa hanya saat Anda melakukan check-in, dan
> tidak dilacak di latar belakang.
>
> [Izinkan] [Tolak]

**Lokasi di kode:**
- `lib/pages/home_page.dart:435-464` — check-in/check-out
- `lib/pages/asset_check_form_page.dart:118-135` — pemeriksaan aset

---

## 4. Content Rating (IARC Questionnaire)

Sagansa adalah **aplikasi bisnis SaaS** untuk manajemen operasional UMKM.
Jawaban IARC:

| Pertanyaan | Jawaban |
|---|---|
| Apakah app mengandung kekerasan? | Tidak |
| Apakah app mengandung seksual/nudity? | Tidak |
| Apakah app mengandung bahasa kasar? | Tidak |
| Apakah app mengandung konten perjudian? | Tidak |
| Apakah app memungkinkan pembelian/pembayaran? | **Ya** (fitur POS & subscription) — tetapi ini transaksi bisnis, bukan gambling |
| Apakah app ditujukan untuk anak-anak? | **Tidak** (target: pengusaha/operator UMKM dewasa) |

Rating yang diharapkan: **Everyone** (atau PEGI 3 / ESRB E).

---

## 5. Target Audience

- **Target audience:** 18+ (dewasa, pelaku bisnis)
- **App bisa menarik anak-anak?** Tidak (kompleksitas fungsional bisnis)
- **Kategori app:** Business / Productivity

Deklarasi "tidak menarik anak-anak" mengurangi review scrutiny untuk policy
anak (COPPA dll).

---

## 6. Keamanan Keystore ⚠️

### Masalah
`my-release-key.jks` **terlanjur ter-commit ke git history** sebelum di-untrack.
Akibatnya, file binary keystore + (jika password pernah ter-commit) password
upload key berpotensi compromised.

### Mitigasi yang SUDAH dilakukan
1. `git rm --cached my-release-key.jks` — untrack dari working tree (file fisik tetap).
2. `.gitignore` diperbarui: `*.jks`, `*.keystore`, `key.properties`.
3. **Play App Signing** dipilih → Google pegang **app signing key** (key yang
   dipakai untuk distribusi ke user). Upload key yang compromised "hanya" bisa
   dipakai untuk upload build baru ke Play Console Anda sendiri — bukan untuk
   meniru app di device user.

### Mitigasi yang DISARANKAN
1. **Ganti password keystore** segera:
   ```bash
   keytool -storepasswd -keystore my-release-key.jks
   keytool -keypasswd -alias upload -keystore my-release-key.jks
   ```
2. **Idealnya: generate upload key baru** dan daftarkan via Play Console:
   - Play Console → Setup → App integrity → "Request upload key reset".
   - Ini membuat upload key lama tidak valid bahkan untuk upload.
3. **Jangan rewrite git history** untuk menghapus keystore lama — bisa break
   collaborator dan tidak menghapus cache di clone/fork yang sudah ada. Anggap
   keystore lama compromised secara permanen dan rotasi key.

### Kenapa tidak fatal
Karena pakai **Play App Signing**, bahkan jika seseorang punya app signing key
Anda, mereka tidak bisa mendistribusikan app sebagai "update" Sagansa ke user
lain — hanya Google yang bisa sign dengan app signing key. Yang mereka bisa lakukan
paling buruk adalah upload build ke Play Console Anda (jika juga punya akses akun).

---

## 7. Catatan untuk Rilis Berikutnya (Modul Lokasi Karyawan)

Saat modul "lokasi on-demand karyawan" diaktifkan kembali, persiapkan:

1. **Aktifkan kembali permission di manifest:**
   - `ACCESS_BACKGROUND_LOCATION`
   - `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`
   - Hapus entri `tools:node="remove"` untuk `FOREGROUND_SERVICE_LOCATION`
     dan `GeolocatorLocationService` di `android/app/src/main/AndroidManifest.xml`
     (lihat catatan manifest merger di bagian 1)
2. **Setup Firebase:**
   - Taruh `google-services.json` di `android/app/`
   - Uncomment plugin `com.google.gms.google-services` di `settings.gradle` & `app/build.gradle`
3. **Prominent disclosure kompleks** (wajib untuk background location):
   - Dialog terpisah SEBELUM request background location
   - Jelaskan: kapan lokasi dikumpul, untuk apa, apakah employee diberi tahu
   - Play menolak formulir generik — harus spesifik untuk use case
4. **Fill out Permissions Declaration Form** di Play Console:
   - Pilih "Employee scheduling" atau "Delivery" use case
   - Sertakan video demo prominent disclosure & flow
5. **Estimasi review:** 3–7 hari kerja, bisa lebih untuk first-time background
   location approval.

---

## Ringkasan Status Rilis Awal

| Item | Status |
|---|---|
| Permission minimal & terjustifikasi | ✅ |
| Tidak ada SDK/permission iklan | ✅ |
| Tidak ada background location | ✅ (dilepas sengaja) |
| Network security config (HTTPS default) | ✅ |
| Data Safety Form mapping | ✅ (siap isi) |
| Keystore di-untrack + .gitignore | ✅ |
| Play App Signing | ✅ (akan setup saat upload) |

**Profil risiko review: RENDAH.** Tidak ada fitur yang butuh manual approval.
Diharapkan lolos review otomatis dalam 1–3 hari.

# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

- Staf operasional restoran (kasir, crew, manager shift): cek dan lengkapi identitas diri di sela operasional toko; frekuensi rendah (sekali saat onboarding/perubahan data) kecuali data rekening.
- Admin/owner: memverifikasi (submit/approve) dan mengunci/membuka profil staf via `admin/profile/:id/status`; melihat detail profil + rekening untuk operasional (mis. payment receipt gaji harian).

## Product Purpose

Sagansa mobile (Flutter, `mobiles/sagansa`, "Sagansa Saas for Restaurant" v1.3.26+54) adalah aplikasi operasional restoran: presensi (clock in/out), kesiapan diri, delivery/procurement, dan profil kepegawaian yang terhubung ke backend recruitment (`GET/POST profile`, `admin/profile`).

Halaman Profil Saya: satu-satunya tempat staf melihat dan melengkapi data pribadi + rekening. Sukses = data valid tersubmit sekali, terkunci setelah approve, rekening tetap bisa diperbaiki tanpa membuka data pribadi.

## Positioning

Bukan profil akun generik (nama/email/password). Ini profil kepegawaian recruitment: submit → approve admin → terkunci; hanya 3 field rekening yang tetap bisa diubah saat terkunci (`bankOnly`), sampai admin melepas kunci (`status` kembali `draft`).

## Operating Context

- Alur: staf isi Data Pribadi + Data Rekening → `POST /profile` → admin review di Detail Profil → `PUT admin/profile/:id/status` (`submitted` = kunci, `draft` = buka). Status terkunci dihitung client: `status in [submitted, accepted, reviewed, rejected] && joinDate != null`.
- Lingkungan: perangkat Android/iOS lapangan (Material 3, light/dark), offline-tidak-dijamin; simpan best-effort dengan snackbar, retry manual.
- Ritual terkait: clock-in/out harian, verifikasi admin sebelum penggajian.

## Capabilities and Constraints

- Konfirmasi: `GET profile` → `{details, experiences}`; `POST /profile` (tidak ada PUT); payload mengabaikan string kosong; saat terkunci hanya `bank_name, bank_account_name, bank_account_number` yang dikirim.
- Konfirmasi: email dan role tidak dapat diubah dari halaman ini; tidak ada mekanisme ganti password di `mobiles/sagansa` saat ini.
- Konfirmasi: admin dapat mengunci (`submitted`) / membuka (`draft`) via Detail Profil; banner kunci tampil saat `_isLocked`.
- Terbuka (belum diputuskan): mekanisme ganti password tersendiri (layar baru vs deep-link ke web); apakah KTP/selfie, gender, anak, pengalaman perlu tampil di Profil Saya atau tetap di recruitment web.
- Batasan teknis: Flutter SDK `>=3.4.3 <4.0.0`, Material 3 `ThemeData` via `ThemeProvider`, token aman di `flutter_secure_storage`, tanpa menambah permission baru.

## Brand Commitments

- Dunia visual incumbent dipertahankan: Elegant Midnight & Gold (`lib/theme/app_colors.dart`: charcoal `#262626`, gold `#E6C687`, champagne canvas `#F2EEE9`, obsidian dark `#121212`), spacing grid 8px (`AppSpacing`), Material 3 light/dark lewat `ThemeProvider`.
- Bahasa: Indonesia, judul "Profil Saya", seksi "Data Pribadi" dan "Data Rekening".

## Evidence on Hand

- `lib/pages/profile_page.dart` (form 14 controller, `_isLocked`, `_save bankOnly`, banner kunci).
- `lib/models/applicant_detail_model.dart` (`toProfilePayload`, `isLocked`).
- `lib/services/user_service.dart` (`getProfile`, `updateProfile`, `setProfileStatus`).
- `lib/pages/admin_profile_detail_page.dart` + `admin_profile_list_page.dart` (pola kunci/buka).
- Tidak ada: endpoint ganti password mobile, goldens/screenshot fixture profil.

## Product Principles

- Sekali benar: profil dirancang untuk diisi sekali dengan valid, bukan diedit tiap hari.
- Kunci berarti aman: status terkunci harus terbaca sebelum tombol apa pun ditekan.
- Rekening selalu bisa diperbaiki: gaji tidak boleh gagal karena data pribadi terkunci.
- Admin memegang kunci: staf tidak bisa membuka kunci sendiri dari client.
- Lapangan dulu: terbaca di cahaya terang/gelap, satu tangan, tanpa jargon HR.

## Accessibility & Inclusion

- Target operasional dengan literasi digital beragam; sentuh ≥48dp, kontras light/dark via `ColorScheme`, pesan error berbahasa Indonesia yang bisa dibaca screen reader. Standar formal belum ditetapkan (terbuka).

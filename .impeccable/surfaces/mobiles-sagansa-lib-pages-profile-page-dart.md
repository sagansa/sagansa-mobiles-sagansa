---
version: 1
slug: "mobiles-sagansa-lib-pages-profile-page-dart"
primary_target: "mobiles/sagansa/lib/pages/profile_page.dart"
related_targets: ["mobiles/sagansa/lib/models/applicant_detail_model.dart","mobiles/sagansa/lib/services/user_service.dart","mobiles/sagansa/lib/pages/admin_profile_detail_page.dart"]
---

# Surface brief — Profil Saya (Flutter)

Scope: `mobiles/sagansa/lib/pages/profile_page.dart` (+ related: `applicant_detail_model.dart`, `user_service.dart`).
Mode: Operate.

Audience & job: staf operasional restoran melengkapi profil kepegawaian sekali saat onboarding; admin mengunci/membuka via Detail Profil.
Action: isi Data Pribadi + Data Rekening → Simpan (`POST /profile`).
States: terbuka (semua edit) vs terkunci (hanya rekening, `bankOnly`); loading, error+retry, saving.
Constraints: API dan logika `isLocked`/`bankOnly` tetap; email/role immutable; belum ada endpoint ganti password — hanya entry point; dunia Midnight & Gold + `AppSpacing` + Material 3 light/dark dipertahankan.

Direction: perjelas status kunci dalam 5 detik; naik dari banner kecil menjadi status header; rekening selalu editable; seksi Keamanan sebagai entry point non-fungsional yang jujur.

Unresolved: mekanisme ganti password native vs deep-link (di luar scope; hanya entry point); apakah KTP/selfie perlu tampil di sini.

## Direction contract

THESIS: Profil yang terkunci harus terbaca sebagai terkunci sebelum tombol apa pun ditekan; halaman ini menolak pola form generik tanpa status.
OWN-WORLD: Midnight & Gold incumbent — charcoal/gold, champagne canvas, kartu Material 3, radius 12, spacing 8px grid; status memakai warna semantik info/error/success yang sudah ada.
STORY: Staf memahami terkunci/terbuka, tahu persis field mana yang bisa diubah, menyimpan rekening tanpa 403; admin tetap pemegang kunci.
FIRST VIEWPORT: Status header (ikon gembok + label TERKUNCI/TERBUKA + satu kalimat konsekuensi) di atas; ringkasan identitas; Data Pribadi sebagai daftar baca saat terkunci; Data Rekening sebagai input aktif; simpan menempel di bawah via SafeBottomBar.
FORM: Perpanjangan permukaan yang ada — bukan identitas baru; concept-seed tidak dijalankan untuk penyempurnaan Operate yang sempit dan spesifik ini.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

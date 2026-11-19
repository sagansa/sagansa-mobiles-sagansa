# Surface brief — Form Tambah/Edit Supplier (Flutter)

Scope: `lib/pages/supplier_form_page.dart` (+ related: `supplier_provider.dart`, `supplier_model.dart`, `supplier_detail_page.dart`).
Mode: Operate.

Audience & job: dua ritme dalam satu form — staf toko/procurement di lokasi supplier (domestik; foto toko, nama, alamat, scan QRIS dari stiker, satu tangan) dan admin di meja (luar negeri; negara, valuta, SWIFT dari invoice). Supplier dibuat sekali, dikoreksi jarang.
Action: isi inti (asal, identitas, lokasi) → simpan; pembayaran (QRIS/rekening) boleh dilengkapi sekarang atau nanti saat edit.
States: pivot Domestik/Luar Negeri (admin saja; non-admin selalu domestik); pembayaran tertunda (kartu lipat) vs terisi (kartu terbuka); loading lookup, error+retry, menyimpan; QRIS memvalidasi/terverifikasi (merchant + NMID).
Constraints: semua field, validasi, payload & `SupplierProvider` tetap; create tanpa pembayaran valid di API (bank/QRIS opsional); foto wajib hanya untuk status Valid; dunia Midnight & Gold + `AppSpacing` + Material 3 light/dark; `AppPageScaffold` + `FormSectionCard` sebagai bahasa form standar.

Direction: Dua Fase — zona INTI (kartu putih solid) vs zona PEMBAYARAN (kartu tonal bergaris putus "bisa dilengkapi nanti"); tombol simpan menyebut keadaan.
Steer dari user: "2" (penegasan kartu kedua, bukan arahan baru). Pertanyaan "apa yang terasa salah" dilewati — tidak ada preferensi dikarang; dipegang prinsip Operate (ekspresi tak boleh mengaburkan tugas/state/affordance).

Unresolved: penanda "pembayaran belum lengkap" di list/detail supplier (fase dua di luar surface ini); tampilan status verifikasi di mode edit.

## Direction contract

THESIS: Simpan inti dulu — pembayaran adalah fase kedua yang jujur dinamai, bukan seksi keempat yang sama beratnya; form ini menolak scroll panjang empat kartu seragam tempat QRIS tenggelam di dasar.
OWN-WORLD: Midnight & Gold incumbent — charcoal/emas di kanvas champagne (obsidian di dark), kartu Material 3 radius 16, field outline radius 12, app bar kaca; zona tertunda = kartu tonal bergaris putus dengan ikon redup, zona inti = kartu putih solid; tanpa warna atau tipe baru.
STORY: Pengguna memilih asal, mengisi identitas & lokasi, dan paham tanpa membaca bahwa pembayaran boleh ditunda; yang di lapangan men-scan QRIS dalam satu ketuk langsung dari kartu tertunda; tombol menyebut "Simpan tanpa pembayaran" atau "Simpan lengkap".
FIRST VIEWPORT: App bar kaca "Tambah Supplier"; segmented Domestik|Luar Negeri selebar layar + satu baris keterangan (admin); kartu Identitas: foto persegi 100 di kiri, Nama* & Telepon bertumpuk di kanan, caption "opsional — wajib sebelum Valid"; kartu Lokasi dimulai (Alamat Lengkap*); bar bawah "Simpan tanpa pembayaran". Kartu Pembayaran bergaris putus muncul saat scroll dengan aksi [Scan QRIS] [Isi manual] (domestik) / [Isi rekening bank] (LN); sekali dibuka jadi kartu solid, tidak dilipat lagi.
FORM: Dua Fase — kandidat #6 dari 7 pada daftar terurut saya; dadu mengocok #4, #6, #7 (#4 memimpin); user mengunci #6. Seed key 5b542432. Challenger tidak menang; disiplin ticket-wallet (yang selesai tetap terlihat) & split-flap (reset cascade terlihat) diadopsi kecil. Code-led: tidak ada image generation.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

import 'package:flutter/material.dart';

import '../../theme/app_button_style.dart';

/// Tombol "tambah baris" standar untuk SEMUA form (Tambah Item, Tambah
/// Biaya, Pilih Invoice, dst.) — satu ukuran seragam antar halaman.
///
/// Sebelumnya tiap halaman menulis `TextButton.icon` sendiri dengan ukuran
/// campur-aduk (default ±40px vs compact ±26px; ikon `add` vs
/// `add_circle_outline`; 16 vs 18) sehingga tombol plus terlihat beda
/// ukuran antar form. Semua varian itu diganti widget ini.
///
/// Kontrak ukuran: ikon plus 18, padding 8/4, tanpa minimum size Material
/// (shrinkWrap) — pas sebagai `trailing` FormSectionCard maupun inline di
/// samping judul seksi. [isLoading] mengganti ikon dengan spinner.
class FormAddButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const FormAddButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add, size: 18),
      label: Text(label),
      style: AppButtonStyle.text(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

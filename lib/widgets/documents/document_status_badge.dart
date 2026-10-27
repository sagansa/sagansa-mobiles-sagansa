import 'package:flutter/material.dart';

import '../../services/document/document_models.dart';
import '../status_badge.dart';

/// Badge status surat — pemetaan warna tunggal untuk list & detail
/// (sebelumnya privat di list page; task 22 memakainya juga di detail).
///
/// Warna design system ([StatusBadge]): draft abu (neutral), menunggu_ttd
/// amber (warning), terbit hijau (success), dicabut oranye (warning outline
/// agar beda dari menunggu_ttd), dibatalkan merah (error).
class DocumentStatusBadge extends StatelessWidget {
  final DocumentModel document;

  const DocumentStatusBadge({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final (type, style) = switch (document.status) {
      'terbit' => (StatusType.success, StatusBadgeStyle.filled),
      'menunggu_ttd' => (StatusType.warning, StatusBadgeStyle.filled),
      'dicabut' => (StatusType.warning, StatusBadgeStyle.outline),
      'dibatalkan' => (StatusType.error, StatusBadgeStyle.filled),
      _ => (StatusType.neutral, StatusBadgeStyle.filled),
    };
    return StatusBadge(
      label: document.statusLabel,
      type: type,
      style: style,
    );
  }
}

library;

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

/// Konversi isi surat antara Quill [Delta] (editor flutter_quill) dan
/// string HTML (`body_html` yang disimpan backend dan dirender dompdf).
///
/// Dua arah, dua strategi (task 20):
///
/// - **Delta → HTML**: konverter sendiri (`deltaToHtml`) yang mendukung
///   ops inti editor fase ini — teks dengan bold/italic, heading h1-h6,
///   list ordered/bullet, paragraf kosong. Tulisan sendiri dipilih karena
///   package `delta_to_html` pub.dev (0.2.2) tidak terawat dan deklarasi
///   SDK-nya `>=2.12.0 <3.0.0` (tak pernah divalidasi di Dart 3), sementara
///   kebutuhan kita kecil dan format keluaran harus presisi kompatibel
///   dengan tag yang dipahami dompdf (`<p>`, `<h1..h6>`, `<ol>`, `<ul>`,
///   `<li>`, `<strong>`, `<em>`, `<br/>`).
///
/// - **HTML → Delta**: `HtmlToDelta` dari `flutter_quill_delta_from_html`
///   (maintainer flutter_quill) — menangani mayoritas HTML template.
///   Tabel/struktur kompleks tetap tidak representabel di Delta fase ini:
///   teksnya dipertahankan datar, pemanggil bertanggung jawab menampilkan
///   peringatan (`hasUnsupportedHtml`).
class QuillHtmlCodec {
  QuillHtmlCodec._();

  /// Delta editor → HTML string siap simpan ke `body_html`.
  ///
  /// Ops non-teks (embed) dilewati diam-diam — editor fase ini tidak
  /// menyediakan embed. Karakter dik-escape agar teks user aman.
  static String deltaToHtml(Delta delta) {
    final buffer = _LineBuffer();
    for (final operation in delta.operations) {
      final data = operation.data;
      if (data is String) {
        buffer.append(data, operation.attributes);
      }
    }
    return buffer.toHtml();
  }

  /// HTML template/draft → Delta untuk prefill editor; null bila HTML
  /// gagal diparse (pemanggil menampilkan editor kosong + peringatan).
  static Delta? tryHtmlToDelta(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return null;
    try {
      return HtmlToDelta().convert(trimmed);
    } catch (_) {
      return null;
    }
  }

  /// True bila HTML memuat struktur yang tidak representabel penuh di
  /// editor fase ini (tabel) — isi teks tetap dikonversi datar, UI
  /// menampilkan peringatan "format sebelumnya tidak dapat diedit penuh".
  static bool hasUnsupportedHtml(String html) =>
      html.toLowerCase().contains('<table');
}

/// Perakit baris dari aliran ops Delta.
///
/// Semantik Quill: atribut BARIS (header/list) hidup pada op yang memuat
/// `\n` penutup baris; atribut INLINE (bold/italic) pada op teks. Satu op
/// bisa memuat beberapa baris ("baris1\nbaris2\n") sehingga string dipecah
/// per karakter baris baru.
class _LineBuffer {
  final List<_Line> _lines = [];
  _Line _current = _Line();

  void append(String text, Map<String, dynamic>? attributes) {
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isNotEmpty) {
        _current.segments.add(_Segment(
          text: part,
          bold: attributes?['bold'] == true,
          italic: attributes?['italic'] == true,
        ));
      }
      if (i < parts.length - 1) {
        // Baris ditutup: atribut op ini menjadi atribut baris.
        _current.header = _asInt(attributes?['header']);
        _current.list = attributes?['list']?.toString();
        _lines.add(_current);
        _current = _Line();
      }
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Render baris menjadi HTML. Newline penutup dokumen (dan baris kosong
  /// beruntun di akhir) tidak menghasilkan elemen.
  String toHtml() {
    _lines.add(_current);
    while (_lines.isNotEmpty && _lines.last.isEmpty) {
      _lines.removeLast();
    }
    final lines = _lines.toList();

    final html = StringBuffer();
    String? openList; // 'ordered' | 'bullet' | null
    for (final line in lines) {
      final listKind = line.list == 'ordered' || line.list == 'bullet'
          ? line.list
          : null;

      if (listKind != openList) {
        if (openList != null) html.write('</${_listTag(openList)}>');
        if (listKind != null) html.write('<${_listTag(listKind)}>');
        openList = listKind;
      }

      final inner = line.segments.map(_segmentToHtml).join();
      if (listKind != null) {
        html.write('<li>$inner</li>');
      } else if (line.header case final header? when header >= 1 && header <= 6) {
        html.write('<h$header>$inner</h$header>');
      } else if (inner.isEmpty) {
        // Baris kosong eksplisit — <br/> agar dompdf tidak menciutkannya.
        html.write('<p><br/></p>');
      } else {
        html.write('<p>$inner</p>');
      }
    }
    if (openList != null) html.write('</${_listTag(openList)}>');

    return html.toString();
  }

  static String _listTag(String? kind) => kind == 'ordered' ? 'ol' : 'ul';

  static String _segmentToHtml(_Segment segment) {
    var text = segment.text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    if (segment.bold) text = '<strong>$text</strong>';
    if (segment.italic) text = '<em>$text</em>';
    return text;
  }
}

class _Line {
  final List<_Segment> segments = [];
  int? header;
  String? list;

  bool get isEmpty => segments.isEmpty && header == null && list == null;
}

class _Segment {
  final String text;
  final bool bold;
  final bool italic;

  const _Segment({
    required this.text,
    required this.bold,
    required this.italic,
  });
}

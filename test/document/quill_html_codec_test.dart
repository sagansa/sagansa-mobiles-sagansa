import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/services/document/quill_html_codec.dart';

/// Konversi Delta ↔ HTML (task 20): ops inti editor — bold/italic,
/// heading h1-h3, list ordered/bullet, escape teks, baris kosong,
/// dan roundtrip HTML→Delta→HTML.
Delta _delta(List<Map<String, dynamic>> ops) => Delta.fromJson(ops);

void main() {
  group('deltaToHtml', () {
    test('paragraf polos + teks di-escape', () {
      final delta = _delta([
        {'insert': 'Ganti <unit> & kantor'},
      ]);
      // Delta dari editor selalu diakhiri newline; op tunggal tanpa \n
      // tetap ditutup sebagai paragraf.
      expect(
        QuillHtmlCodec.deltaToHtml(delta),
        '<p>Ganti &lt;unit&gt; &amp; kantor</p>',
      );
    });

    test('bold dan italic inline', () {
      final delta = _delta([
        {'insert': ' Biasa '},
        {'insert': 'tebal', 'attributes': {'bold': true}},
        {'insert': ' '},
        {'insert': 'miring', 'attributes': {'italic': true}},
        {'insert': 'keduanya\n', 'attributes': {'bold': true, 'italic': true}},
      ]);
      expect(
        QuillHtmlCodec.deltaToHtml(delta),
        '<p> Biasa <strong>tebal</strong> <em>miring</em>'
        '<em><strong>keduanya</strong></em></p>',
      );
    });

    test('heading h1-h3 dari atribut baris', () {
      final delta = _delta([
        {'insert': 'Judul Besar\n', 'attributes': {'header': 1}},
        {'insert': 'Sub Judul\n', 'attributes': {'header': 2}},
        {'insert': 'Bagian\n', 'attributes': {'header': 3}},
        {'insert': 'Paragraf biasa\n'},
      ]);
      expect(
        QuillHtmlCodec.deltaToHtml(delta),
        '<h1>Judul Besar</h1><h2>Sub Judul</h2><h3>Bagian</h3>'
        '<p>Paragraf biasa</p>',
      );
    });

    test('list ordered & bullet — berurutan sama digrouping satu elemen',
        () {
      final delta = _delta([
        {'insert': 'Pertama'},
        {'insert': '\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'Kedua'},
        {'insert': '\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'Butir A'},
        {'insert': '\n', 'attributes': {'list': 'bullet'}},
        {'insert': 'Butir B'},
        {'insert': '\n', 'attributes': {'list': 'bullet'}},
        {'insert': 'Penutup\n'},
      ]);
      expect(
        QuillHtmlCodec.deltaToHtml(delta),
        '<ol><li>Pertama</li><li>Kedua</li></ol>'
        '<ul><li>Butir A</li><li>Butir B</li></ul>'
        '<p>Penutup</p>',
      );
    });

    test('list berganti jenis ditutup-dibuka lagi', () {
      final delta = _delta([
        {'insert': 'Satu'},
        {'insert': '\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'Dua'},
        {'insert': '\n', 'attributes': {'list': 'bullet'}},
      ]);
      expect(
        QuillHtmlCodec.deltaToHtml(delta),
        '<ol><li>Satu</li></ol><ul><li>Dua</li></ul>',
      );
    });

    test('newline penutup dokumen tidak menghasilkan paragraf ekstra', () {
      final delta = _delta([
        {'insert': 'Satu baris saja\n'},
      ]);
      expect(QuillHtmlCodec.deltaToHtml(delta), '<p>Satu baris saja</p>');
    });

    test('baris kosong eksplisit menjadi <p><br/></p>', () {
      final delta = _delta([
        {'insert': 'Atas\n'},
        {'insert': '\n'},
        {'insert': 'Bawah\n'},
      ]);
      expect(
        QuillHtmlCodec.deltaToHtml(delta),
        '<p>Atas</p><p><br/></p><p>Bawah</p>',
      );
    });

    test('delta kosong → string kosong', () {
      expect(QuillHtmlCodec.deltaToHtml(Delta()), '');
    });
  });

  group('HTML → Delta', () {
    test('roundtrip HTML inti (p/h1/ol/ul/strong/em)', () {
      const html = '<h1>Judul</h1>'
          '<p>Isi dengan <strong>tebal</strong> dan <em>miring</em>.</p>'
          '<ol><li>Satu</li><li>Dua</li></ol>'
          '<ul><li>Butir</li></ul>';

      final delta = QuillHtmlCodec.tryHtmlToDelta(html);
      expect(delta, isNotNull);
      final back = QuillHtmlCodec.deltaToHtml(delta!);
      expect(back, contains('<h1>Judul</h1>'));
      expect(back, contains('<strong>tebal</strong>'));
      expect(back, contains('<em>miring</em>'));
      expect(back, contains('<ol><li>Satu</li><li>Dua</li></ol>'));
      expect(back, contains('<ul><li>Butir</li></ul>'));
    });

    test('HTML kosong → null', () {
      expect(QuillHtmlCodec.tryHtmlToDelta(''), isNull);
      expect(QuillHtmlCodec.tryHtmlToDelta('   '), isNull);
    });

    test('deteksi tabel tidak didukung', () {
      expect(
        QuillHtmlCodec.hasUnsupportedHtml('<p>ok</p><table><tr><td>x</td>'),
        isTrue,
      );
      expect(QuillHtmlCodec.hasUnsupportedHtml('<p>ok</p>'), isFalse);
    });
  });
}

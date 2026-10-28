import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/services/document/incoming_models.dart';
import 'package:sagansa/widgets/documents/letter_thread_timeline.dart';

/// Kontrak UI `LetterThreadTimeline` (Task 10 fase 1b) — permukaan runutan
/// surat lintas jenis:
/// - node tampil urut kronologis payload; arah terbaca dari chip
///   Masuk (kiri) / Keluar (kanan) + label relasi kecil di antara node;
/// - node saat ini (pasangan type+id) disorot "Surat ini";
/// - tap kartu memanggil callback dengan node terkait;
/// - thread kosong → state "Surat berdiri sendiri".

ThreadNodeModel _node(
  String type,
  String id,
  String number, {
  String? relation,
  int depth = 0,
  String? party,
  DateTime? date,
}) =>
    ThreadNodeModel(
      type: type,
      id: id,
      number: number,
      date: date ?? DateTime(2026, 10, 1),
      partyName: party,
      relationToParent: relation,
      depth: depth,
    );

/// Runutan bercabang 4 node: surat keluar akar → balasan masuk →
/// tindak lanjut keluar (depth 2) + referensi masuk ke akar (depth 1).
final _branchingThread = ThreadModel(
  rootType: 'document',
  rootId: 'doc-1',
  total: 4,
  nodes: [
    _node('document', 'doc-1', '010/ST/DIR/X/2026', party: 'PT Mitra Jaya'),
    _node('incoming_letter', 'il-1', 'SM-001/X/2026',
        relation: 'balasan', depth: 1, party: 'PT Mitra Jaya'),
    _node('document', 'doc-2', '011/ST/DIR/X/2026',
        relation: 'tindak_lanjut', depth: 2, party: 'PT Mitra Jaya'),
    _node('incoming_letter', 'il-9', 'SM-009/X/2026',
        relation: 'referensi', depth: 1, party: 'Kantor Notaris'),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('runutan bercabang: urutan node, chip arah, label relasi, '
      'dan node saat ini disorot', (tester) async {
    await _pump(
      tester,
      ListView(
        children: [
          LetterThreadTimeline(
            thread: _branchingThread,
            currentNodeType: 'incoming_letter',
            currentNodeId: 'il-1',
          ),
        ],
      ),
    );

    // Urutan render = urutan kronologis payload ( atas → bawah ).
    final numbers = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((text) => text.contains('2026'))
        .toList(growable: false);
    expect(numbers.indexOf('010/ST/DIR/X/2026'), lessThan(numbers.indexOf('SM-001/X/2026')));
    expect(numbers.indexOf('SM-001/X/2026'), lessThan(numbers.indexOf('011/ST/DIR/X/2026')));
    expect(numbers.indexOf('011/ST/DIR/X/2026'), lessThan(numbers.indexOf('SM-009/X/2026')));

    // Chip arah: 2 Masuk (incoming) + 2 Keluar (document) — chip kiri/kanan
    // di dalam kartu + ikon gutter memakai label yang sama.
    expect(find.text('Masuk'), findsNWidgets(2));
    expect(find.text('Keluar'), findsNWidgets(2));

    // Label relasi ke parent di antara node (akar tanpa label).
    expect(find.text('Membalas'), findsOneWidget);
    expect(find.text('Menindaklanjuti'), findsOneWidget);
    expect(find.text('Mereferensikan'), findsOneWidget);

    // Node saat ini disorot + pihak terbaca sekali lihat.
    expect(find.text('Surat ini'), findsOneWidget);
    expect(find.text('1 Okt 2026 • PT Mitra Jaya'), findsWidgets);
    expect(find.text('1 Okt 2026 • Kantor Notaris'), findsOneWidget);
  });

  testWidgets('tap kartu node memanggil callback dengan node terkait',
      (tester) async {
    final tapped = <ThreadNodeModel>[];
    await _pump(
      tester,
      ListView(
        children: [
          LetterThreadTimeline(
            thread: _branchingThread,
            currentNodeType: 'incoming_letter',
            currentNodeId: 'il-1',
            onNodeTap: tapped.add,
          ),
        ],
      ),
    );

    await tester.tap(find.text('010/ST/DIR/X/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SM-009/X/2026'));
    await tester.pumpAndSettle();

    expect(tapped.length, 2);
    expect(tapped[0].id, 'doc-1');
    expect(tapped[0].type, 'document');
    expect(tapped[1].id, 'il-9');
    expect(tapped[1].type, 'incoming_letter');
  });

  testWidgets('tanpa currentNode: tidak ada sorotan "Surat ini"',
      (tester) async {
    await _pump(
      tester,
      ListView(
        children: [LetterThreadTimeline(thread: _branchingThread)],
      ),
    );
    expect(find.text('Surat ini'), findsNothing);
    expect(find.text('SM-001/X/2026'), findsOneWidget);
  });

  testWidgets('thread kosong: state "Surat berdiri sendiri"', (tester) async {
    await _pump(
      tester,
      const Center(
        child: LetterThreadTimeline(
          thread: ThreadModel(rootType: 'document', rootId: 'doc-1'),
        ),
      ),
    );
    expect(find.text('Surat berdiri sendiri — belum ada runutan.'),
        findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
    expect(find.text('Keluar'), findsNothing);
  });
}

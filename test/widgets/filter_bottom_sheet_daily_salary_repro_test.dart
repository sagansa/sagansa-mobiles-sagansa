import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/filter_bottom_sheet.dart';

/// Regresi crash 1.3.18+43: sheet filter Daily Salary gagal di-build dengan
/// `'(List<(int, String)>, dynamic) => ...' is not a subtype of
/// '((List<(dynamic, String)>, dynamic) => ...)?'` ketika field Karyawan
/// (dependsOn + optionFilter) dibangun lewat tipe mentah. Konfigurasi field
/// & closure disalin persis dari `_DailySalaryPageState._openFilterSheet`.
void main() {
  final employees = [
    {'id': 1, 'name': 'Budi', 'is_former_employee': false},
    {'id': 2, 'name': 'Siti', 'is_former_employee': true},
    {'id': 3, 'name': 'Anton', 'is_former_employee': 0},
  ];

  List<FilterField> dailySalaryFields() {
    return [
      const DropdownFilterField<String>(
        label: 'Status Karyawan',
        value: null,
        options: [
          ('active', 'Karyawan Aktif'),
          ('former', 'Mantan Karyawan'),
        ],
      ),
      DropdownFilterField<int>(
        label: 'Karyawan',
        value: null,
        options: employees.map((e) {
          final name = e['name']?.toString() ?? 'Karyawan #${e['id']}';
          final isFormer =
              e['is_former_employee'] == true || e['is_former_employee'] == 1;
          return (
            e['id'] as int,
            isFormer ? '$name (Mantan Karyawan)' : name,
          );
        }).toList(),
        dependsOn: 'Status Karyawan',
        optionFilter: (options, status) => status == null
            ? options
            : options
                .where((opt) => employees.any((e) =>
                    e['id'] == opt.$1 &&
                    (status == 'former') ==
                        (e['is_former_employee'] == true ||
                            e['is_former_employee'] == 1)))
                .toList(),
      ),
      const DropdownFilterField<String>(
        label: 'Status',
        value: null,
        options: [
          ('1', 'Belum Dibayar'),
          ('2', 'Sudah Dibayar'),
        ],
      ),
    ];
  }

  Future<void> pumpOpener(WidgetTester tester,
      {void Function(Map<String, dynamic>)? onApply}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => FilterBottomSheet.show(
              context,
              fields: dailySalaryFields(),
              onApply: onApply ?? (_) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
  }

  testWidgets('sheet filter daily salary ter-build tanpa TypeError',
      (tester) async {
    await pumpOpener(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Sebelum fix: build gagal dengan TypeError covariance saat field
    // Karyawan (dependsOn/optionFilter) dibangun → seluruh sheet jadi
    // ErrorWidget dan semua finder ini kosong.
    expect(find.text('Pilih Status Karyawan'), findsOneWidget);
    expect(find.text('Pilih Karyawan'), findsOneWidget);
    expect(find.text('Pilih Status'), findsOneWidget);
    expect(find.text('Terapkan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pilih Status Karyawan → Karyawan terfilter → Terapkan',
      (tester) async {
    Map<String, dynamic>? applied;
    await pumpOpener(tester, onApply: (values) => applied = values);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Buka dropdown "Status Karyawan" dan pilih "Karyawan Aktif".
    // Picker modern memakai baris InkWell berlabel (bukan Radio).
    await tester.tap(find.text('Pilih Status Karyawan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Karyawan Aktif'));
    await tester.pumpAndSettle();

    // Dropdown "Karyawan" kini memuat hanya karyawan aktif (Siti terfilter).
    await tester.tap(find.text('Pilih Karyawan'));
    await tester.pumpAndSettle();
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Anton'), findsOneWidget);
    expect(find.text('Siti (Mantan Karyawan)'), findsNothing);

    await tester.tap(find.text('Budi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    // Nilai yang sampai ke onApply harus lolos cast seperti di halaman
    // (as int? / as String?).
    expect(applied, isNotNull);
    expect(applied!['Status Karyawan'] as String?, 'active');
    expect(applied!['Karyawan'] as int?, 1);
  });
}

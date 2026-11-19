import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/sop_model.dart';

void main() {
  group('SopCategoryModel.fromJson', () {
    test('membaca kategori lengkap dengan jumlah SOP', () {
      final c = SopCategoryModel.fromJson({
        'id': 3,
        'name': 'Buka Toko',
        'icon': 'sunrise',
        'sops_count': 5,
      });
      expect(c.id, 3);
      expect(c.name, 'Buka Toko');
      expect(c.icon, 'sunrise');
      expect(c.sopsCount, 5);
    });

    test('toleran terhadap field null/absent', () {
      final c = SopCategoryModel.fromJson({'id': 1, 'name': 'Kebersihan'});
      expect(c.icon, isNull);
      expect(c.sopsCount, 0);
    });
  });

  group('SopStepModel.fromJson', () {
    test('membaca langkah bergambar', () {
      final s = SopStepModel.fromJson({
        'id': 9,
        'title': 'Nyalakan mesin kasir',
        'description': 'Tekan tombol power 3 detik.',
        'image': 'images/Sop/abc.webp',
        'requires_photo': false,
      });
      expect(s.title, 'Nyalakan mesin kasir');
      expect(s.requiresPhoto, isFalse);
      // Path relatif diselesaikan ke URL img service.
      expect(s.imageUrl, contains('img.sagansa.id/storage/images/Sop/abc.webp'));
    });

    test('path absolut tidak diprefix ulang', () {
      final s = SopStepModel.fromJson({
        'id': 1,
        'title': 'x',
        'image': 'https://img.sagansa.id/storage/images/Sop/z.webp',
      });
      expect(s.imageUrl,
          'https://img.sagansa.id/storage/images/Sop/z.webp');
    });

    test('gambar null → imageUrl null', () {
      final s = SopStepModel.fromJson({'id': 1, 'title': 'x'});
      expect(s.imageUrl, isNull);
    });
  });

  group('SopModel.fromJson', () {
    test('payload list: kategori nested + steps_count tanpa steps', () {
      final m = SopModel.fromJson({
        'id': 12,
        'title': 'SOP Tutup Toko',
        'description': 'Rangkaian menutup toko.',
        'cover_image': null,
        'sop_category_id': 2,
        'category': {'id': 2, 'name': 'Tutup Toko', 'icon': 'moon'},
        'revision': 4,
        'steps_count': 7,
      });
      expect(m.title, 'SOP Tutup Toko');
      expect(m.categoryId, 2);
      expect(m.categoryName, 'Tutup Toko');
      expect(m.revision, 4);
      expect(m.steps, isEmpty);
      expect(m.hasSteps, isFalse);
      // totalStepCount jatuh ke steps_count saat steps kosong.
      expect(m.totalStepCount, 7);
      expect(m.coverImageUrl, isNull);
    });

    test('payload detail: langkah terurut terbaca', () {
      final m = SopModel.fromJson({
        'id': 12,
        'title': 'SOP Buka Toko',
        'description': null,
        'cover_image': 'images/Sop/cover.webp',
        'category': null,
        'revision': 1,
        'steps': [
          {'id': 1, 'title': 'Buka pintu', 'description': 'Pukul 06.30.'},
          {'id': 2, 'title': 'Cek listrik', 'image': 'images/Sop/2.webp'},
        ],
      });
      expect(m.steps.length, 2);
      expect(m.hasSteps, isTrue);
      expect(m.steps[0].title, 'Buka pintu');
      expect(m.steps[1].imageUrl, isNotNull);
      expect(m.totalStepCount, 2);
      expect(m.coverImageUrl, contains('images/Sop/cover.webp'));
      expect(m.categoryName, isNull);
    });

    test('requires_photo terbaca (hook fase C)', () {
      final m = SopModel.fromJson({
        'id': 1,
        'title': 'x',
        'steps': [
          {'id': 1, 'title': 'Foto etalase', 'requires_photo': true},
        ],
      });
      expect(m.steps.first.requiresPhoto, isTrue);
    });
  });
}

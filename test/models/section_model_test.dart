import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/subclasses/section.dart';

void main() {
  group('Section Model Tests', () {
    test('toMap and fromMap round-trip', () {
      final section = Section(
        id: 's1',
        name: 'Work',
        order: 1,
        userId: 'u1',
      );

      final map = section.toMap();
      final reconstructed = Section.fromMap(map, 's1');

      expect(reconstructed.id, 's1');
      expect(reconstructed.name, 'Work');
      expect(reconstructed.order, 1);
      expect(reconstructed.userId, 'u1');
    });

    test('fromMap handles missing fields', () {
      final map = <String, dynamic>{};

      final section = Section.fromMap(map, 's2');

      expect(section.id, 's2');
      expect(section.name, '');
      expect(section.order, 0);
      expect(section.userId, '');
    });

    test('copyWith should work correctly', () {
      final section = Section(
        id: 's1',
        name: 'Old name',
        order: 0,
        userId: 'u1',
      );

      final updated = section.copyWith(name: 'New name', order: 2);

      expect(updated.name, 'New name');
      expect(updated.order, 2);
      expect(updated.id, 's1');
      expect(updated.userId, 'u1');
    });

    test('copyWith preserves unchanged fields', () {
      final section = Section(
        id: 's1',
        name: 'Name',
        order: 1,
        userId: 'u1',
      );

      final updated = section.copyWith(name: 'Renamed');

      expect(updated.order, 1);
      expect(updated.userId, 'u1');
    });
  });
}

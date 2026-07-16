import 'package:dojo/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser', () {
    test('parses intern profile and role capabilities', () {
      final user = AppUser.fromJson({
        'id': 12,
        'email': 'intern@example.com',
        'role': 'Intern',
        'name': 'Nama Intern',
        'intern': {'id': 4, 'number': 'INT-004'},
      });

      expect(user.id, 12);
      expect(user.isIntern, isTrue);
      expect(user.isMentor, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.initials, 'NI');
      expect(user.intern?['number'], 'INT-004');
    });

    test('treats HRD and Headmaster as attendance admins', () {
      final hrd = AppUser.fromJson({
        'id': 1,
        'email': 'hrd@example.com',
        'role': 'HRD',
        'name': 'Human Resources',
      });
      final headmaster = AppUser.fromJson({
        'id': 2,
        'email': 'head@example.com',
        'role': 'Headmaster',
        'name': 'Head Master',
      });

      expect(hrd.isAdmin, isTrue);
      expect(headmaster.isAdmin, isTrue);
      expect(hrd.roleLabel, 'Human Resources');
      expect(headmaster.roleLabel, 'Headmaster');
    });
  });
}

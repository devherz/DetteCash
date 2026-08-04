import 'package:flutter_test/flutter_test.dart';
import 'package:dettecash/models/audit_log.dart';

void main() {
  group('AuditLog Model Tests', () {
    test('AuditLog serialization and deserialization', () {
      final now = DateTime.now();
      final log = AuditLog(
        id: 1,
        action: 'AJOUT_DETTE',
        details: 'Montant: 5000 FCFA',
        timestamp: now,
        userName: 'Admin',
      );

      final map = log.toMap();
      expect(map['id'], 1);
      expect(map['action'], 'AJOUT_DETTE');
      expect(map['details'], 'Montant: 5000 FCFA');
      expect(map['user_name'], 'Admin');

      final fromMapLog = AuditLog.fromMap(map);
      expect(fromMapLog.id, 1);
      expect(fromMapLog.action, 'AJOUT_DETTE');
      expect(fromMapLog.details, 'Montant: 5000 FCFA');
      expect(fromMapLog.userName, 'Admin');
    });
  });
}

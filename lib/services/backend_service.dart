import '../database/db_helper.dart';
import '../models/audit_log.dart';

/// Decoupled service managing backend, data integrity, audit logging, and maintenance operations.
class BackendService {
  static final BackendService instance = BackendService._init();

  BackendService._init();

  /// Logs a business or system event to the audit trail
  Future<void> logEvent({
    required String action,
    required String details,
    String? userName,
  }) async {
    final log = AuditLog(
      action: action,
      details: details,
      timestamp: DateTime.now(),
      userName: userName ?? 'System',
    );
    await DatabaseHelper.instance.insertAuditLog(log);
  }

  /// Retrieve the audit trail history
  Future<List<AuditLog>> getAuditHistory({int limit = 100}) async {
    return await DatabaseHelper.instance.getAuditLogs(limit: limit);
  }

  /// Performs database defragmentation (VACUUM and index optimization)
  Future<void> optimizeDatabase() async {
    await DatabaseHelper.instance.vacuumDatabase();
    await logEvent(
      action: 'MAINTENANCE_VACUUM',
      details: 'Optimisation et défragmentation de la base SQLite effectuées.',
    );
  }

  /// Get database metrics (size, record counts)
  Future<Map<String, dynamic>> getHealthStats() async {
    return await DatabaseHelper.instance.getDatabaseStats();
  }

  /// Export the full database state into a formatted JSON string
  Future<String> exportFullJson() async {
    await logEvent(
      action: 'EXPORT_JSON',
      details: 'Exportation complète des données au format JSON.',
    );
    return await DatabaseHelper.instance.exportDatabaseToJson();
  }
}

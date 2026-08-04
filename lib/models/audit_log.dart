class AuditLog {
  final int? id;
  final String action;
  final String details;
  final DateTime timestamp;
  final String? userName;

  AuditLog({
    this.id,
    required this.action,
    required this.details,
    required this.timestamp,
    this.userName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'user_name': userName,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as int?,
      action: map['action'] as String,
      details: map['details'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      userName: map['user_name'] as String?,
    );
  }

  @override
  String toString() {
    return 'AuditLog(id: $id, action: $action, details: $details, timestamp: $timestamp, userName: $userName)';
  }
}

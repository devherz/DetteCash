import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import '../models/commerce.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/audit_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dettecash.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints support in SQLite
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE "transaction" 
        ADD COLUMN parent_transaction_id INTEGER REFERENCES "transaction"(id) ON DELETE SET NULL
      ''');
    }
    if (oldVersion < 3) {
      // 1. Create USER table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS "user" (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          telephone TEXT NOT NULL UNIQUE,
          mot_de_passe TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'USER'
        )
      ''');

      // Seed default admin if user table is empty
      final userCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM "user"'));
      if (userCount == 0) {
        await db.insert('"user"', {
          'nom': 'Admin',
          'telephone': '00000000',
          'mot_de_passe': '1234',
          'role': 'ADMIN',
        });
      }

      // 2. Add date_echeance to transaction table if missing
      try {
        await db.execute('ALTER TABLE "transaction" ADD COLUMN date_echeance TEXT');
      } catch (_) {}

      // 3. Add custom_whatsapp_template to commerce table if missing
      try {
        await db.execute('ALTER TABLE commerce ADD COLUMN custom_whatsapp_template TEXT');
      } catch (_) {}

      // 4. Create performance indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_client ON "transaction"(client_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_parent ON "transaction"(parent_transaction_id)');
    }

    if (oldVersion < 4) {
      // 5. Create AUDIT_LOG table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          details TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          user_name TEXT
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Create COMMERCE table
    await db.execute('''
      CREATE TABLE commerce (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom_commerce TEXT NOT NULL,
        telephone_commerce TEXT NOT NULL,
        adresse_commerce TEXT,
        logo_path TEXT,
        custom_whatsapp_template TEXT
      )
    ''');

    // 2. Create CLIENT table
    await db.execute('''
      CREATE TABLE client (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commerce_id INTEGER NOT NULL,
        nom_complet TEXT NOT NULL,
        telephone TEXT NOT NULL,
        date_creation TEXT NOT NULL,
        FOREIGN KEY (commerce_id) REFERENCES commerce (id) ON DELETE CASCADE
      )
    ''');

    // 3. Create TRANSACTION table (using escaped name "transaction" due to SQL keyword conflict)
    await db.execute('''
      CREATE TABLE "transaction" (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        type_transaction TEXT NOT NULL,
        montant REAL NOT NULL,
        date_transaction TEXT NOT NULL,
        description TEXT,
        photo_path TEXT,
        parent_transaction_id INTEGER,
        date_echeance TEXT,
        FOREIGN KEY (client_id) REFERENCES client (id) ON DELETE CASCADE,
        FOREIGN KEY (parent_transaction_id) REFERENCES "transaction" (id) ON DELETE SET NULL
      )
    ''');

    // Create performance indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_client ON "transaction"(client_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_parent ON "transaction"(parent_transaction_id)');

    // 4. Create USER table
    await db.execute('''
      CREATE TABLE "user" (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT NOT NULL UNIQUE,
        mot_de_passe TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'USER'
      )
    ''');

    // Seed default admin user
    await db.insert('"user"', {
      'nom': 'Admin',
      'telephone': '00000000',
      'mot_de_passe': '1234',
      'role': 'ADMIN',
    });

    // 5. Create AUDIT_LOG table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        details TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        user_name TEXT
      )
    ''');
  }

  // ==========================================
  // COMMERCE CRUD Operations
  // ==========================================

  Future<int> insertCommerce(Commerce commerce) async {
    final db = await instance.database;
    return await db.insert('commerce', commerce.toMap());
  }

  Future<Commerce?> getCommerce(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'commerce',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Commerce.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Commerce>> getAllCommerces() async {
    final db = await instance.database;
    final result = await db.query('commerce');
    return result.map((json) => Commerce.fromMap(json)).toList();
  }

  Future<int> updateCommerce(Commerce commerce) async {
    final db = await instance.database;
    return await db.update(
      'commerce',
      commerce.toMap(),
      where: 'id = ?',
      whereArgs: [commerce.id],
    );
  }

  Future<int> deleteCommerce(int id) async {
    final db = await instance.database;
    return await db.delete(
      'commerce',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // CLIENT CRUD Operations
  // ==========================================

  Future<int> insertClient(Client client) async {
    final db = await instance.database;
    return await db.insert('client', client.toMap());
  }

  Future<Client?> getClient(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'client',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Client.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Client>> getClientsForCommerce(int commerceId) async {
    final db = await instance.database;
    final result = await db.query(
      'client',
      where: 'commerce_id = ?',
      whereArgs: [commerceId],
      orderBy: 'nom_complet ASC',
    );
    return result.map((json) => Client.fromMap(json)).toList();
  }

  Future<int> updateClient(Client client) async {
    final db = await instance.database;
    return await db.update(
      'client',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<int> deleteClient(int id) async {
    final db = await instance.database;
    return await db.delete(
      'client',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // TRANSACTION CRUD Operations
  // ==========================================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    int insertedId = 0;

    await db.transaction((txn) async {
      insertedId = await txn.insert('"transaction"', transaction.toMap());

      // Log audit
      await txn.insert('audit_log', {
        'action': transaction.typeTransaction == TransactionType.dette ? 'AJOUT_DETTE' : 'REGLEMENT',
        'details': 'Montant: ${transaction.montant} FCFA (Client ID: ${transaction.clientId})',
        'timestamp': DateTime.now().toIso8601String(),
        'user_name': 'System',
      });

      // Check if settled
      if (transaction.typeTransaction == TransactionType.paiement && transaction.parentTransactionId != null) {
        final result = await txn.rawQuery('''
          SELECT 
            t.montant as original_amount,
            COALESCE((SELECT SUM(p.montant) FROM "transaction" p WHERE p.parent_transaction_id = t.id), 0.0) as total_payments
          FROM "transaction" t
          WHERE t.id = ?
        ''', [transaction.parentTransactionId]);

        if (result.isNotEmpty) {
          final double original = (result.first['original_amount'] as num).toDouble();
          final double totalPayments = (result.first['total_payments'] as num).toDouble();
          final double remaining = original - totalPayments;
          
          if (remaining <= 0.0) {
            try {
              await createBackup();
            } catch (_) {}
          }
        }
      }
    });

    return insertedId;
  }

  Future<TransactionModel?> getTransaction(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      '"transaction"',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return TransactionModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<TransactionModel>> getTransactionsForClient(int clientId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        t.*,
        (t.montant - COALESCE((SELECT SUM(p.montant) FROM "transaction" p WHERE p.parent_transaction_id = t.id), 0.0)) as remaining_amount
      FROM "transaction" t
      WHERE t.client_id = ?
      ORDER BY t.date_transaction DESC
    ''', [clientId]);
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  /// Fetch all unpaid or partially paid DETTE transactions for a specific client.
  Future<List<TransactionModel>> getUnpaidDebtsForClient(int clientId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        t.*,
        (t.montant - COALESCE((SELECT SUM(p.montant) FROM "transaction" p WHERE p.parent_transaction_id = t.id), 0.0)) as remaining_amount
      FROM "transaction" t
      WHERE t.client_id = ? 
        AND t.type_transaction = 'DETTE'
        AND (t.montant - COALESCE((SELECT SUM(p.montant) FROM "transaction" p WHERE p.parent_transaction_id = t.id), 0.0)) > 0.0
      ORDER BY t.date_transaction ASC
    ''', [clientId]);
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.update(
      '"transaction"',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      '"transaction"',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // Advanced Queries & Business Logic
  // ==========================================

  /// Fetch all clients of a commerce along with their total debts, total payments,
  /// and current net balance.
  /// Net Balance formula: Total Debts (DETTE) - Total Payments (PAIEMENT).
  /// A positive balance means the client owes money (debtor).
  /// A negative balance means the client has overpaid or is a creditor.
  Future<List<ClientBalanceInfo>> getClientsWithBalances(int commerceId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        c.id,
        c.commerce_id,
        c.nom_complet,
        c.telephone,
        c.date_creation,
        COALESCE(SUM(CASE WHEN t.type_transaction = 'DETTE' THEN t.montant ELSE 0 END), 0.0) as total_dette,
        COALESCE(SUM(CASE WHEN t.type_transaction = 'PAIEMENT' THEN t.montant ELSE 0 END), 0.0) as total_paiement
      FROM client c
      LEFT JOIN "transaction" t ON c.id = t.client_id
      WHERE c.commerce_id = ?
      GROUP BY c.id, c.commerce_id, c.nom_complet, c.telephone, c.date_creation
      ORDER BY c.nom_complet ASC
    ''', [commerceId]);

    return result.map((row) {
      final client = Client(
        id: row['id'] as int,
        commerceId: row['commerce_id'] as int,
        nomComplet: row['nom_complet'] as String,
        telephone: row['telephone'] as String,
        dateCreation: DateTime.parse(row['date_creation'] as String),
      );
      final double totalDette = (row['total_dette'] as num).toDouble();
      final double totalPaiement = (row['total_paiement'] as num).toDouble();
      return ClientBalanceInfo(
        client: client,
        totalDette: totalDette,
        totalPaiement: totalPaiement,
      );
    }).toList();
  }

  // ==========================================
  // LOCAL BACKUP & RESTORE Operations
  // ==========================================

  /// Get the directory where backups are stored.
  Future<Directory> getBackupDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDirPath = join(docsDir.path, 'dettecash_backups');
    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Create a new local backup of the SQLite database.
  Future<File> createBackup() async {
    // 1. Get database path
    final dbPath = await getDatabasesPath();
    final activeDbPath = join(dbPath, 'dettecash.db');
    final activeDbFile = File(activeDbPath);

    if (!await activeDbFile.exists()) {
      throw FileSystemException("Active database file not found", activeDbPath);
    }

    // 2. Close active connection to prevent file locking/corruption
    await close();

    // 3. Define backup destination path
    final backupDir = await getBackupDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupFilePath = join(backupDir.path, 'backup_$timestamp.db');
    final backupFile = File(backupFilePath);

    // 4. Copy database file
    await activeDbFile.copy(backupFile.path);

    // 5. Reinitialize active database connection
    await database;

    return backupFile;
  }

  /// Restore a local backup.
  /// WARNING: This will overwrite the current database file.
  Future<void> restoreBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw FileSystemException("Backup file not found", backupFile.path);
    }

    // 1. Close active connection
    await close();

    // 2. Get database path
    final dbPath = await getDatabasesPath();
    final activeDbPath = join(dbPath, 'dettecash.db');

    // 3. Copy backup file over active database
    await backupFile.copy(activeDbPath);

    // 4. Reinitialize active database connection
    await database;
  }

  /// List all available local backup files.
  Future<List<File>> listBackups() async {
    final backupDir = await getBackupDirectory();
    final List<FileSystemEntity> entities = await backupDir.list().toList();
    final List<File> files = [];

    for (var entity in entities) {
      if (entity is File && extension(entity.path) == '.db') {
        files.add(entity);
      }
    }

    // Sort backups by modification time (newest first)
    files.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    return files;
  }

  /// Delete a backup file.
  Future<void> deleteBackup(File backupFile) async {
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  }

  /// Share a backup file using system share dialog (WhatsApp, Email, Drive, etc.)
  Future<void> shareBackup(File backupFile) async {
    if (await backupFile.exists()) {
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'Sauvegarde DetteCash : ${backupFile.path.split(Platform.pathSeparator).last}',
      );
    }
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
  // ==========================================
  // USER CRUD Operations
  // ==========================================

  Future<int> insertUser(UserModel user) async {
    final db = await instance.database;
    return await db.insert('"user"', user.toMap());
  }

  Future<UserModel?> getUser(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      '"user"',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await instance.database;
    final result = await db.query('"user"', orderBy: 'nom ASC');
    return result.map((json) => UserModel.fromMap(json)).toList();
  }

  Future<int> updateUser(UserModel user) async {
    final db = await instance.database;
    return await db.update(
      '"user"',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete(
      '"user"',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // AUDIT LOG & MAINTENANCE OPERATIONS
  // ==========================================

  Future<int> insertAuditLog(AuditLog log) async {
    final db = await instance.database;
    return await db.insert('audit_log', log.toMap());
  }

  Future<List<AuditLog>> getAuditLogs({int limit = 100}) async {
    final db = await instance.database;
    final maps = await db.query(
      'audit_log',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((json) => AuditLog.fromMap(json)).toList();
  }

  /// Run SQLite VACUUM and OPTIMIZE to defragment and reduce database file size.
  Future<void> vacuumDatabase() async {
    final db = await instance.database;
    await db.execute('PRAGMA optimize');
    await db.execute('VACUUM');
  }

  /// Retrieve database metrics (file size in bytes, total record counts).
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await instance.database;
    final dbPath = await getDatabasesPath();
    final file = File(join(dbPath, 'dettecash.db'));
    
    int size = 0;
    if (await file.exists()) {
      size = await file.length();
    }

    final clientCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM client')) ?? 0;
    final transactionCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM "transaction"')) ?? 0;
    final auditCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM audit_log')) ?? 0;

    final String sizeFormatted = '${(size / 1024).toStringAsFixed(1)} KB';

    return {
      'fileSizeBytes': size,
      'sizeFormatted': sizeFormatted,
      'clientCount': clientCount,
      'transactionCount': transactionCount,
      'auditCount': auditCount,
    };
  }

  /// Export complete database content into a structured JSON string.
  Future<String> exportDatabaseToJson() async {
    final db = await instance.database;
    final commerces = await db.query('commerce');
    final clients = await db.query('client');
    final transactions = await db.query('"transaction"');
    final users = await db.query('"user"');
    final auditLogs = await db.query('audit_log');

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': 4,
      'commerce': commerces,
      'client': clients,
      'transaction': transactions,
      'user': users,
      'audit_log': auditLogs,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

/// Helper model class to hold Client along with aggregated balance details.
class ClientBalanceInfo {
  final Client client;
  final double totalDette;
  final double totalPaiement;

  ClientBalanceInfo({
    required this.client,
    required this.totalDette,
    required this.totalPaiement,
  });

  /// Net balance: what the client currently owes (dette - paiement)
  double get solde => totalDette - totalPaiement;

  @override
  String toString() {
    return 'ClientBalanceInfo(client: ${client.nomComplet}, totalDette: $totalDette, totalPaiement: $totalPaiement, solde: $solde)';
  }
}

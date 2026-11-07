import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Future<Database>? _database;
  static String? _pathOverride;

  /// Versión actual del esquema.
  static const int schemaVersion = 5;

  DatabaseHelper._init();

  /// Cierra la base abierta y hace que la próxima apertura use [path]
  /// (por ejemplo, `inMemoryDatabasePath`). Solo para pruebas.
  @visibleForTesting
  static Future<void> resetForTests({String? path}) async {
    final abierta = _database;
    _database = null;
    _pathOverride = path;
    if (abierta != null) await (await abierta).close();
  }

  // Se guarda el Future para que dos llamadas simultáneas compartan la misma apertura.
  Future<Database> get database => _database ??= _initDB('conecta_market.db');

  Future<Database> _initDB(String filePath) async {
    final path = _pathOverride ?? join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: schemaVersion,
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
    );
  }

  static Future<void> createSchema(Database db, int version) async {
    // Tabla de Proveedores
    await db.execute('''
      CREATE TABLE providers (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        ruc TEXT,
        telefono TEXT
      )
    ''');

    // Tabla de Productos
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        stock REAL DEFAULT 0,
        umbralAlerta INTEGER DEFAULT 5,
        precio REAL DEFAULT 0
      )
    ''');

    // Tabla de Recibos (Cabecera)
    await db.execute('''
      CREATE TABLE receipts (
        id TEXT PRIMARY KEY,
        provider_id TEXT NULL,
        fecha TEXT,
        total REAL,
        tipomovimiento INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0,
        serie TEXT DEFAULT 'B001',
        FOREIGN KEY (provider_id) REFERENCES providers(id)
      )
    ''');

    // Tabla de Items de Recibos (Detalle)
    await db.execute('''
      CREATE TABLE receipt_items (
        id TEXT PRIMARY KEY,
        receipt_id TEXT,
        product_id TEXT,
        cantidad REAL,
        costoUnitario REAL,
        FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
  }

  static Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE receipts ADD COLUMN synced INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE receipts ADD COLUMN serie TEXT DEFAULT 'B001'");
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE products ADD COLUMN precio REAL DEFAULT 0');
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
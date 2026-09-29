import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Ruta alternativa usada solo por las pruebas (por ejemplo
  /// `inMemoryDatabasePath`). En produccion siempre es null.
  static String? _overridePath;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('conecta_market.db');
    return _database!;
  }

  /// Cierra la conexion en cache y apunta la base a [path] para la siguiente
  /// apertura. Permite que cada prueba arranque con una base limpia.
  @visibleForTesting
  static Future<void> resetForTesting({String? path}) async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _overridePath = path;
  }

  Future<Database> _initDB(String filePath) async {
    final String path;
    if (_overridePath != null) {
      path = _overridePath!;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
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

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('conecta_market.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
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
        umbralAlerta INTEGER DEFAULT 5
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
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
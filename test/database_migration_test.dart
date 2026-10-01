import 'dart:io';

import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/repositories/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Verifica que una base ya existente en la versión 4 (sin precio ni
/// bodega_id) migre de forma acumulativa hasta la versión 6 sin perder datos.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('conectamarket_migration_');
    dbPath = '${tempDir.path}${Platform.pathSeparator}legacy.db';

    // Base en el esquema anterior: products sin columna precio.
    final legacy = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              nombre TEXT NOT NULL,
              stock REAL DEFAULT 0,
              umbralAlerta INTEGER DEFAULT 5
            )
          ''');
          await db.execute('''
            CREATE TABLE receipts (
              id TEXT PRIMARY KEY,
              provider_id TEXT NULL,
              fecha TEXT,
              total REAL,
              tipomovimiento INTEGER DEFAULT 0,
              synced INTEGER DEFAULT 0,
              serie TEXT DEFAULT 'B001'
            )
          ''');
          await db.execute('''
            CREATE TABLE receipt_items (
              id TEXT PRIMARY KEY,
              receipt_id TEXT,
              product_id TEXT,
              cantidad REAL,
              costoUnitario REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE providers (
              id TEXT PRIMARY KEY,
              nombre TEXT NOT NULL,
              ruc TEXT,
              telefono TEXT
            )
          ''');
        },
      ),
    );
    await legacy.insert('products', {
      'id': 'P001',
      'nombre': 'Arroz Costeño 1kg',
      'stock': 24.0,
      'umbralAlerta': 5,
    });
    await legacy.close();

    await DatabaseHelper.resetForTesting(path: dbPath);
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting(path: dbPath);
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // El archivo puede quedar bloqueado un instante en Windows.
    }
  });

  Future<List<String>> columnasDe(String tabla) async {
    final db = await DatabaseHelper.instance.database;
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    return info.map((c) => c['name'] as String).toList();
  }

  test('al abrir una base v4 se agrega products.precio con valor 0', () async {
    final db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), 6);

    expect(await columnasDe('products'), contains('precio'));

    // El producto que ya existía se conserva y su precio queda en 0.
    final producto = (await ProductRepository().getAllProducts()).firstWhere((p) => p.id == 'P001');
    expect(producto.nombre, 'Arroz Costeño 1kg');
    expect(producto.stock, 24);
    expect(producto.precio, 0);
  });

  test('al abrir una base v4 se agrega bodega_id en providers/products/receipts, no en receipt_items', () async {
    await DatabaseHelper.instance.database;

    expect(await columnasDe('providers'), contains('bodega_id'));
    expect(await columnasDe('products'), contains('bodega_id'));
    expect(await columnasDe('receipts'), contains('bodega_id'));
    // receipt_items no lleva bodega_id propio: se deriva via receipt_id.
    expect(await columnasDe('receipt_items'), isNot(contains('bodega_id')));
  });

  test('tras la migración se puede guardar un producto con precio', () async {
    final repo = ProductRepository();
    await repo.upsertProduct(
      Product(id: 'P002', nombre: 'Gaseosa Inca Kola 500ml', stock: 12, umbralAlerta: 4, precio: 3.50),
    );

    final guardado = (await repo.getAllProducts()).firstWhere((p) => p.id == 'P002');
    expect(guardado.precio, 3.50);
  });
}

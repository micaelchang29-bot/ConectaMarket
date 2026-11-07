import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:sqflite/sqflite.dart';


class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Insertar o actualizar producto (Upsert). Lo usan la importación y la restauración.
  Future<void> upsertProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Alta de un producto nuevo: un SKU repetido falla en lugar de sobrescribir.
  Future<void> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<Product?> getProductById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Product.fromMap(maps.first);
  }

  // Obtener todos los productos
  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: 'nombre COLLATE NOCASE');

    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  // Cantidad de líneas de comprobantes (ventas o compras) que usan el producto
  Future<int> countMovementsByProduct(String productId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM receipt_items WHERE product_id = ?',
      [productId],
    );
    return (result.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<int> countAllMovements() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS n FROM receipt_items');
    return (result.first['n'] as num?)?.toInt() ?? 0;
  }

  // Eliminar producto
  Future<void> deleteProduct(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Eliminar todos los productos
  Future<void> deleteAllProducts() async {
    final db = await _dbHelper.database;
    await db.delete('products');
  }

  // Obtener productos críticos (según umbral)
  Future<List<Product>> getLowStockProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'stock <= umbralAlerta',
    );

    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }
}

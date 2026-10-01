import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/services/auth_service.dart';
import 'package:sqflite/sqflite.dart';


class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Insertar o actualizar producto (Upsert)
  Future<void> upsertProduct(Product product) async {
    final db = await _dbHelper.database;

    // bodega_id identifica al dueño original de la fila: se estampa una sola
    // vez, en el alta. REPLACE INTO reemplaza la fila completa, así que en
    // una edición hay que reafirmar el valor ya existente explícitamente o se
    // perdería (quedaría NULL) aunque nadie haya cambiado de sesión.
    final existing = await db.query(
      'products',
      columns: ['bodega_id'],
      where: 'id = ?',
      whereArgs: [product.id],
    );
    final String? bodegaId = existing.isNotEmpty
        ? existing.first['bodega_id'] as String?
        : AuthService.instance.currentUid;

    await db.insert(
      'products',
      {...product.toMap(), 'bodega_id': bodegaId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener todos los productos
  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  // Contar movimientos (items de recibo) asociados a un producto
  Future<int> countMovementsByProduct(String productId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM receipt_items WHERE product_id = ?',
      [productId],
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
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
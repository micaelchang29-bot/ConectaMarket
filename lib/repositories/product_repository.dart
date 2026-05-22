import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:sqflite/sqflite.dart';


class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Insertar o actualizar producto (Upsert)
  Future<void> upsertProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.insert(
      'products',
      product.toMap(),
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
import 'package:sqflite/sqflite.dart';
import '../repositories/database_helper.dart';
import '../models/providers_model.dart';

class ProviderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Insertar o actualizar proveedor (Upsert)
  Future<void> upsertProvider(Provider provider) async {
    final db = await _dbHelper.database;
    await db.insert(
      'providers',
      provider.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener todos los proveedores
  Future<List<Provider>> getAllProviders() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('providers');
    
    return List.generate(maps.length, (i) => Provider.fromMap(maps[i]));
  }

  // Obtener proveedor por nombre (case-insensitive, para vincular importaciones CSV)
  Future<Provider?> getProviderByNombre(String nombre) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'providers',
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [nombre.trim()],
    );

    if (maps.isNotEmpty) {
      return Provider.fromMap(maps.first);
    }
    return null;
  }

  // Obtener proveedor por ID
  Future<Provider?> getProviderById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'providers',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return Provider.fromMap(maps.first);
    }
    return null;
  }

  // Eliminar proveedor
  Future<void> deleteProvider(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'providers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  /// Obtiene el histórico de precios de compra cobrados por cada proveedor 
  /// para un producto específico, ordenados desde el más reciente.
  /// Esto provee las variables de entrada (Dataset local) para la IA.
  Future<List<Map<String, dynamic>>> getPurchaseHistoryByProduct(String productId) async {
    final db = await _dbHelper.database;

    // Realizamos un INNER JOIN relacional de 3 tablas: Detalle -> Cabecera -> Proveedor
    // Filtramos solo por movimientos donde tipomovimiento = 1 (Compras)
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        p.id AS provider_id,
        p.nombre AS provider_name,
        ri.costoUnitario AS cost,
        r.fecha AS date
      FROM receipt_items ri
      INNER JOIN receipts r ON ri.receipt_id = r.id
      INNER JOIN providers p ON r.provider_id = p.id
      WHERE ri.product_id = ? AND r.tipomovimiento = 1
      ORDER BY r.fecha DESC
    ''', [productId]);

    return result;
  }
}
import 'package:sqflite/sqflite.dart';
import '../repositories/database_helper.dart';
import '../models/providers_model.dart';
import '../services/auth_service.dart';
import '../services/uid_provider.dart';

class ProviderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Ver product_repository.dart: misma fuente de uid inyectable para poder
  // testear el estampado con un uid real (H5).
  final UidProvider _uidProvider;

  ProviderRepository({UidProvider? uidProvider}) : _uidProvider = uidProvider ?? AuthService.instance;

  // Insertar o actualizar proveedor (Upsert)
  Future<void> upsertProvider(Provider provider) async {
    final db = await _dbHelper.database;

    // Mismo criterio que en product_repository.dart: bodega_id se estampa
    // solo en el alta y se preserva en cada edición posterior.
    final existing = await db.query(
      'providers',
      columns: ['bodega_id'],
      where: 'id = ?',
      whereArgs: [provider.id],
    );
    final String? bodegaId = existing.isNotEmpty
        ? existing.first['bodega_id'] as String?
        : _uidProvider.currentUid;

    await db.insert(
      'providers',
      {...provider.toMap(), 'bodega_id': bodegaId},
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

  // Contar recibos (movimientos) asociados a un proveedor
  Future<int> countReceiptsByProvider(String providerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM receipts WHERE provider_id = ?',
      [providerId],
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
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

  // Eliminar todos los proveedores
  Future<void> deleteAllProviders() async {
    final db = await _dbHelper.database;
    await db.delete('providers');
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
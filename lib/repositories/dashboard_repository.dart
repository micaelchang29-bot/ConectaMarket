import '../repositories/database_helper.dart';

class DashboardRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Extrae físicamente los productos que se encuentran bajo su umbral de alerta
  Future<List<Map<String, dynamic>>> getRawCriticalProducts() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT id, nombre, stock, umbralAlerta
      FROM products
      WHERE stock <= umbralAlerta
      ORDER BY stock ASC
    ''');
  }

  /// Obtiene todos los productos con stock bajo con información adicional
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT
        id,
        nombre,
        stock,
        umbralAlerta,
        CAST(umbralAlerta - stock as INTEGER) as unidadesFaltantes,
        CASE
          WHEN stock = 0 THEN 'Agotado'
          WHEN stock <= umbralAlerta * 0.25 THEN 'Crítico'
          ELSE 'Bajo'
        END as estadoStock
      FROM products
      WHERE stock <= umbralAlerta
      ORDER BY stock ASC
    ''');
  }

  /// Ejecuta la consulta relacional con un INNER JOIN agrupado cronológicamente
  /// para extraer las series de tiempo requeridas por el modelo de ML.
  Future<List<Map<String, dynamic>>> getRawSalesHistory(String productId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        r.fecha as date,
        SUM(ri.cantidad) as total_qty
      FROM receipt_items ri
      INNER JOIN receipts r ON ri.receipt_id = r.id
      WHERE ri.product_id = ? AND r.tipomovimiento = 0
      GROUP BY r.fecha
      ORDER BY r.fecha ASC
    ''', [productId]);
  }

  /// Obtiene el producto más vendido (mayor cantidad acumulada en ventas)
  Future<Map<String, dynamic>?> getMostSoldProduct() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT
          ri.product_id,
          p.nombre,
          SUM(ri.cantidad) as total_quantity
        FROM receipt_items ri
        INNER JOIN receipts r ON ri.receipt_id = r.id
        INNER JOIN products p ON ri.product_id = p.id
        WHERE r.tipomovimiento = 0
        GROUP BY ri.product_id
        ORDER BY total_quantity DESC
        LIMIT 1
      ''');
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error en getMostSoldProduct: $e');
      return null;
    }
  }

  /// Obtiene el producto más rentable (mayor ganancia: ventas - costos)
  Future<Map<String, dynamic>?> getMostProfitableProduct() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT
          ri.product_id,
          p.nombre,
          SUM(CASE
            WHEN r.tipomovimiento = 0 THEN ri.cantidad * ri.costoUnitario
            ELSE -(ri.cantidad * ri.costoUnitario)
          END) as ganancia
        FROM receipt_items ri
        INNER JOIN receipts r ON ri.receipt_id = r.id
        INNER JOIN products p ON ri.product_id = p.id
        GROUP BY ri.product_id
        ORDER BY ganancia DESC
        LIMIT 1
      ''');
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error en getMostProfitableProduct: $e');
      return null;
    }
  }

  /// Obtiene el producto más vendido del mes especificado
  Future<Map<String, dynamic>?> getMostSoldProductByMonth(int year, int month) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT
          ri.product_id,
          p.nombre,
          SUM(ri.cantidad) as total_quantity
        FROM receipt_items ri
        INNER JOIN receipts r ON ri.receipt_id = r.id
        INNER JOIN products p ON ri.product_id = p.id
        WHERE r.tipomovimiento = 0
          AND strftime('%Y', r.fecha) = ?
          AND strftime('%m', r.fecha) = ?
        GROUP BY ri.product_id
        ORDER BY total_quantity DESC
        LIMIT 1
      ''', [year.toString(), month.toString().padLeft(2, '0')]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error en getMostSoldProductByMonth: $e');
      return null;
    }
  }

  /// Obtiene el producto más rentable del mes especificado
  Future<Map<String, dynamic>?> getMostProfitableProductByMonth(int year, int month) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT
          ri.product_id,
          p.nombre,
          SUM(CASE
            WHEN r.tipomovimiento = 0 THEN ri.cantidad * ri.costoUnitario
            ELSE -(ri.cantidad * ri.costoUnitario)
          END) as ganancia
        FROM receipt_items ri
        INNER JOIN receipts r ON ri.receipt_id = r.id
        INNER JOIN products p ON ri.product_id = p.id
        WHERE strftime('%Y', r.fecha) = ?
          AND strftime('%m', r.fecha) = ?
        GROUP BY ri.product_id
        ORDER BY ganancia DESC
        LIMIT 1
      ''', [year.toString(), month.toString().padLeft(2, '0')]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error en getMostProfitableProductByMonth: $e');
      return null;
    }
  }

  /// Obtiene los movimientos recientes de inventario (últimas 50 transacciones)
  Future<List<Map<String, dynamic>>> getRecentMovements({int limit = 50}) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT
        ri.id,
        ri.product_id,
        p.nombre,
        ri.cantidad,
        r.fecha,
        r.tipomovimiento,
        ri.costoUnitario
      FROM receipt_items ri
      INNER JOIN receipts r ON ri.receipt_id = r.id
      INNER JOIN products p ON ri.product_id = p.id
      ORDER BY r.fecha DESC
      LIMIT ?
    ''', [limit]);
  }
}
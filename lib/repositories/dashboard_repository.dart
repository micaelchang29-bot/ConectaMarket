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
        DATE(r.fecha) as date,
        SUM(ri.cantidad) as total_qty
      FROM receipt_items ri
      INNER JOIN receipts r ON ri.receipt_id = r.id
      WHERE ri.product_id = ? AND r.tipomovimiento = 0
      GROUP BY DATE(r.fecha)
      ORDER BY DATE(r.fecha) ASC
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

  /// ML Pair Providers: Ranking global de proveedores por confiabilidad
  Future<List<Map<String, dynamic>>> getProviderRanking() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      WITH provider_stats AS (
        SELECT
          prov.id,
          prov.nombre,
          COUNT(DISTINCT r.id) as num_compras,
          COUNT(DISTINCT ri.product_id) as num_productos,
          AVG(CAST(ri.costoUnitario as REAL)) as avg_price,
          CASE
            WHEN AVG(CAST(ri.costoUnitario as REAL)) > 0
              THEN (MAX(CAST(ri.costoUnitario as REAL)) - MIN(CAST(ri.costoUnitario as REAL)))
                   / AVG(CAST(ri.costoUnitario as REAL)) * 100
            ELSE 0
          END as cv_price,
          CAST((julianday('now') - julianday(MAX(r.fecha))) as INTEGER) as days_since_last
        FROM receipt_items ri
        INNER JOIN receipts r ON ri.receipt_id = r.id
        INNER JOIN providers prov ON r.provider_id = prov.id
        WHERE r.tipomovimiento = 0
        AND r.fecha >= date('now', '-365 days')
        GROUP BY prov.id
      ),
      scored AS (
        SELECT *,
          (30 * MIN(CAST(num_compras * 10 as REAL), 100) +
           30 * MAX(0.0, 100 - cv_price) +
           20 * CASE WHEN days_since_last < 30 THEN 100 WHEN days_since_last < 60 THEN 80 ELSE 50 END +
           20 * MIN(CAST(num_productos * 5 as REAL), 100)) / 100 as raw_score
        FROM provider_stats
      )
      SELECT
        id,
        nombre,
        num_compras,
        num_productos,
        CAST(avg_price as REAL) as avg_price,
        CAST(cv_price as REAL) as cv_price,
        days_since_last,
        CAST(raw_score as INTEGER) as global_score,
        CASE
          WHEN raw_score >= 90 THEN 'EXCELENTE'
          WHEN raw_score >= 75 THEN 'BUENO'
          WHEN raw_score >= 60 THEN 'ACEPTABLE'
          ELSE 'PROBLEMÁTICO'
        END as recommendation
      FROM scored
      ORDER BY raw_score DESC
    ''');
  }

  /// ML Pair Providers: Comparar proveedores para un producto específico
  Future<List<Map<String, dynamic>>> getProvidersForProduct(String productId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      WITH product_global_avg AS (
        SELECT AVG(CAST(costoUnitario as REAL)) as g_avg
        FROM receipt_items
        WHERE product_id = ?
      ),
      provider_product AS (
        SELECT
          prov.id as provider_id,
          prov.nombre as provider_nombre,
          p.nombre as product_nombre,
          COUNT(r.id) as num_compras,
          AVG(CAST(ri.costoUnitario as REAL)) as avg_price,
          CASE
            WHEN AVG(CAST(ri.costoUnitario as REAL)) > 0
              THEN (MAX(CAST(ri.costoUnitario as REAL)) - MIN(CAST(ri.costoUnitario as REAL)))
                   / AVG(CAST(ri.costoUnitario as REAL)) * 100
            ELSE 0
          END as cv_price,
          CASE
            WHEN AVG(CAST(ri.cantidad as REAL)) > 0
              THEN (MAX(CAST(ri.cantidad as REAL)) - MIN(CAST(ri.cantidad as REAL)))
                   / AVG(CAST(ri.cantidad as REAL)) * 100
            ELSE 0
          END as cv_qty,
          CAST((julianday('now') - julianday(MAX(r.fecha))) as INTEGER) as days_since_last,
          SUM(ri.cantidad) as total_quantity
        FROM receipt_items ri
        INNER JOIN receipts r ON ri.receipt_id = r.id
        INNER JOIN providers prov ON r.provider_id = prov.id
        INNER JOIN products p ON ri.product_id = p.id
        WHERE r.tipomovimiento = 0
        AND ri.product_id = ?
        AND r.fecha >= date('now', '-365 days')
        GROUP BY prov.id
      ),
      scored AS (
        SELECT
          pp.*,
          (40 * MAX(0.0, 100 - ABS((avg_price - (SELECT g_avg FROM product_global_avg)) / MAX((SELECT g_avg FROM product_global_avg), 0.01) * 100)) +
           30 * MAX(0.0, 100 - (cv_price + cv_qty) / 2.0) +
           20 * CASE WHEN days_since_last < 30 THEN 100 WHEN days_since_last < 60 THEN 80 ELSE 60 END +
           10 * MIN(CAST(num_compras * 10 as REAL), 100)) / 100 as raw_score
        FROM provider_product pp
      )
      SELECT
        provider_id,
        provider_nombre,
        product_nombre,
        num_compras,
        CAST(avg_price as REAL) as avg_price,
        CAST(cv_price as REAL) as cv_price,
        CAST(cv_qty as REAL) as cv_qty,
        CAST(total_quantity as REAL) as total_quantity,
        days_since_last,
        CAST(raw_score as INTEGER) as provider_score,
        CASE
          WHEN raw_score >= 90 THEN 'EXCELENTE'
          WHEN raw_score >= 75 THEN 'BUENO'
          WHEN raw_score >= 60 THEN 'ACEPTABLE'
          ELSE 'PROBLEMÁTICO'
        END as recommendation
      FROM scored
      ORDER BY raw_score DESC
    ''', [productId, productId]);
  }

  /// Retorna id y nombre de todos los productos
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('SELECT id, nombre FROM products');
  }

  /// Retorna id, nombre, stock y umbralAlerta de todos los productos para el motor de riesgo
  Future<List<Map<String, dynamic>>> getAllProductsWithStock() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('SELECT id, nombre, stock, umbralAlerta FROM products');
  }

  /// ML Pair 1: Calcula métricas de rotación e inventario para clasificación de riesgo
  Future<List<Map<String, dynamic>>> getInventoryRiskMetrics() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      WITH daily_sales AS (
        SELECT
          ri.product_id,
          COUNT(DISTINCT DATE(r.fecha)) as days_with_sales,
          SUM(ri.cantidad) as total_quantity,
          AVG(ri.cantidad) as avg_daily_qty
        FROM receipt_items ri
        INNER JOIN receipts r ON ri.receipt_id = r.id
        WHERE r.tipomovimiento = 0
        AND r.fecha >= date('now', '-30 days')
        GROUP BY ri.product_id
      )
      SELECT
        p.id,
        p.nombre,
        p.stock,
        p.umbralAlerta,
        COALESCE(ds.avg_daily_qty, 1.0) as avg_daily_qty,
        CAST(p.stock / NULLIF(COALESCE(ds.avg_daily_qty, 1.0), 0) as INTEGER) as rotation_days,
        CASE
          WHEN p.stock / NULLIF(COALESCE(ds.avg_daily_qty, 1.0), 0) > 15 THEN 'BAJO'
          WHEN p.stock / NULLIF(COALESCE(ds.avg_daily_qty, 1.0), 0) BETWEEN 8 AND 15 THEN 'MEDIO'
          WHEN p.stock / NULLIF(COALESCE(ds.avg_daily_qty, 1.0), 0) BETWEEN 4 AND 7 THEN 'ALTO'
          ELSE 'CRÍTICO'
        END as risk_level,
        CASE
          WHEN p.stock / NULLIF(COALESCE(ds.avg_daily_qty, 1.0), 0) > 15 THEN 0
          WHEN p.stock / NULLIF(COALESCE(ds.avg_daily_qty, 1.0), 0) BETWEEN 8 AND 15 THEN 1
          WHEN p.stock / NULLIF(COALESCE(ds.avg_daily_qty, 1.0), 0) BETWEEN 4 AND 7 THEN 2
          ELSE 3
        END as risk_score
      FROM products p
      LEFT JOIN daily_sales ds ON p.id = ds.product_id
      ORDER BY risk_score DESC, rotation_days ASC
    ''');
  }
}
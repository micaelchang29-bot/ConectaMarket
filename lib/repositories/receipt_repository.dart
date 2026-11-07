import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/utils/validaciones.dart';
import 'package:sqflite/sqflite.dart';


class ReceiptRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. Guardar Recibo con sus Items (Transacción).
  // Si el recibo ya existía (edición), primero se revierte su efecto en el stock
  // y se reemplazan sus ítems. Ningún stock puede quedar negativo.
  Future<void> saveFullReceipt(Receipt receipt, List<ReceiptItem> items) async {
    if (items.isEmpty) {
      throw const AppException("No se puede registrar un recibo sin ítems.");
    }
    for (final item in items) {
      if (item.cantidad <= 0) {
        throw const AppException("La cantidad de cada producto debe ser mayor que 0.");
      }
    }

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Efecto neto en el stock por producto
      final Map<String, double> delta = {};
      // Stock que se libera al revertir la versión anterior (para el mensaje)
      final Map<String, double> revertido = {};
      final Map<String, double> solicitadoVenta = {};

      final anterior = await txn.query('receipts', where: 'id = ?', whereArgs: [receipt.id]);
      if (anterior.isNotEmpty) {
        final bool eraCompra = (anterior.first['tipomovimiento'] ?? 0) == 1;
        final itemsAnteriores =
            await txn.query('receipt_items', where: 'receipt_id = ?', whereArgs: [receipt.id]);
        for (final it in itemsAnteriores) {
          final pid = it['product_id'].toString();
          final qty = (it['cantidad'] as num).toDouble();
          final efecto = eraCompra ? -qty : qty;
          delta[pid] = (delta[pid] ?? 0) + efecto;
          revertido[pid] = (revertido[pid] ?? 0) + efecto;
        }
        await txn.delete('receipt_items', where: 'receipt_id = ?', whereArgs: [receipt.id]);
      }

      for (final item in items) {
        final efecto = receipt.tipomovimiento ? item.cantidad : -item.cantidad;
        delta[item.productId] = (delta[item.productId] ?? 0) + efecto;
        if (!receipt.tipomovimiento) {
          solicitadoVenta[item.productId] = (solicitadoVenta[item.productId] ?? 0) + item.cantidad;
        }
      }

      await _aplicarDeltas(txn, delta, solicitadoVenta: solicitadoVenta, revertido: revertido);

      await txn.insert('receipts', receipt.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in items) {
        await txn.insert('receipt_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Aplica los cambios de stock dentro de [txn]. Si alguno deja el stock
  /// negativo, lanza [AppException] y la transacción se revierte entera.
  Future<void> _aplicarDeltas(
    Transaction txn,
    Map<String, double> delta, {
    Map<String, double> solicitadoVenta = const {},
    Map<String, double> revertido = const {},
    bool esBorrado = false,
  }) async {
    for (final entry in delta.entries) {
      final productResult = await txn.query('products', where: 'id = ?', whereArgs: [entry.key]);
      if (productResult.isEmpty) {
        if (esBorrado) continue; // el producto ya no existe: nada que revertir
        throw AppException("El producto con SKU ${entry.key} no existe.");
      }
      final nombre = productResult.first['nombre'].toString();
      final double actual = (productResult.first['stock'] as num).toDouble();
      final double nuevo = actual + entry.value;

      if (nuevo < 0) {
        if (esBorrado) {
          throw AppException(
            "No se puede eliminar el comprobante: el stock de $nombre quedaría en "
            "${formatoCantidad(nuevo)} (disponible ${formatoCantidad(actual)}).",
          );
        }
        final disponible = actual + (revertido[entry.key] ?? 0);
        final solicitado = solicitadoVenta[entry.key];
        if (solicitado != null) {
          throw AppException(
            "Stock insuficiente para $nombre: disponible ${formatoCantidad(disponible)}, "
            "solicitado ${formatoCantidad(solicitado)}.",
          );
        }
        throw AppException(
          "No se puede guardar el cambio: el stock de $nombre quedaría en ${formatoCantidad(nuevo)}.",
        );
      }

      await txn.update('products', {'stock': nuevo}, where: 'id = ?', whereArgs: [entry.key]);
    }
  }

  // Restore: inserta recibo + items sin tocar el stock (el snapshot ya lo tiene correcto)
  Future<void> insertReceiptForRestore(Map<String, dynamic> receipt, List<Map<String, dynamic>> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('receipts', receipt, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in items) {
        await txn.insert('receipt_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // 2. Obtener todos los recibos (Maestro)
  Future<List<Receipt>> getAllReceipts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('receipts');
    return List.generate(maps.length, (i) => Receipt.fromMap(maps[i]));
  }

  /// Recibos con sus líneas (producto y cantidad) y el nombre del proveedor,
  /// del más reciente al más antiguo. Una fila por línea; un recibo sin ítems
  /// aparece con product_id nulo.
  Future<List<Map<String, dynamic>>> getReceiptLines() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT
        r.id, r.provider_id, r.fecha, r.total, r.tipomovimiento, r.serie,
        prov.nombre AS provider_nombre,
        ri.product_id, p.nombre AS product_nombre, ri.cantidad
      FROM receipts r
      LEFT JOIN providers prov ON prov.id = r.provider_id
      LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
      LEFT JOIN products p ON p.id = ri.product_id
      ORDER BY r.fecha DESC, r.id DESC, ri.id ASC
    ''');
  }

  // 3. Obtener ítems de un recibo específico (Detalle)
  Future<List<ReceiptItem>> getItemsByReceiptId(String receiptId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipt_items',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
    return List.generate(maps.length, (i) => ReceiptItem.fromMap(maps[i]));
  }

  // 4. Eliminar Recibo: revierte su efecto en el stock y borra sus ítems.
  Future<void> deleteReceipt(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rec = await txn.query('receipts', where: 'id = ?', whereArgs: [id]);
      if (rec.isEmpty) return;
      final bool esCompra = (rec.first['tipomovimiento'] ?? 0) == 1;
      final items = await txn.query('receipt_items', where: 'receipt_id = ?', whereArgs: [id]);

      final Map<String, double> delta = {};
      for (final it in items) {
        final pid = it['product_id'].toString();
        final qty = (it['cantidad'] as num).toDouble();
        delta[pid] = (delta[pid] ?? 0) + (esCompra ? -qty : qty);
      }
      await _aplicarDeltas(txn, delta, esBorrado: true);

      await txn.delete('receipt_items', where: 'receipt_id = ?', whereArgs: [id]);
      await txn.delete('receipts', where: 'id = ?', whereArgs: [id]);
    });
  }

  // 5. Eliminar Todos los Recibos y Detalles
  Future<void> deleteAllReceipts() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('receipt_items');
      await txn.delete('receipts');
    });
  }

  Future<List<Map<String, dynamic>>> getSalesForPeriod(String startDate, String endDate) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT id, serie, fecha, total
      FROM receipts
      WHERE tipomovimiento = 0
        AND date(fecha) >= date(?)
        AND date(fecha) <= date(?)
      ORDER BY date(fecha) ASC
    ''', [startDate, endDate]);
  }

  /// Extrae el desglose relacional de ítems comprados y vendidos acotados
  /// en un rango de fechas para el cálculo preciso del balance financiero.
  Future<List<Map<String, dynamic>>> getDetailedBalanceItemsInRange(String startDate, String endDate) async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
      SELECT
        date(r.fecha) as fecha,
        r.tipomovimiento,
        ri.cantidad,
        ri.costoUnitario
      FROM receipt_items ri
      INNER JOIN receipts r ON ri.receipt_id = r.id
      WHERE date(r.fecha) >= date(?) AND date(r.fecha) <= date(?)
      ORDER BY date(r.fecha) ASC
    ''', [startDate, endDate]);
  }

}
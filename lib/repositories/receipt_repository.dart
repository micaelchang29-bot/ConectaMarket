import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:sqflite/sqflite.dart';


class ReceiptRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. Guardar Recibo con sus Items (Transacción)
  Future<void> saveFullReceipt(Receipt receipt, List<ReceiptItem> items) async {
    if (items.isEmpty) {
      throw Exception("No se puede registrar un recibo sin ítems.");
    }
    
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // Insertar Cabecera
      await txn.insert(
        'receipts', 
        receipt.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace
      );
      
      // Insertar cada ítem del detalle
      for (var item in items) {
        await txn.insert(
          'receipt_items', 
          item.toMap(), 
          conflictAlgorithm: ConflictAlgorithm.replace
        );

        // Actualizar Stock de forma atómica
        final List<Map<String, Object?>> productResult = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        if (productResult.isEmpty) {
          throw Exception("El producto con ID ${item.productId} no existe.");
        }

        final double currentStock = (productResult.first['stock'] as num).toDouble();
        final double qty = item.cantidad;
        // 1 (true) es compra (aumenta stock), 0 (false) es venta (disminuye stock)
        final double newStock = receipt.tipomovimiento ? (currentStock + qty) : (currentStock - qty);

        await txn.update(
          'products',
          {'stock': newStock},
          where: 'id = ?',
          whereArgs: [item.productId],
        );
      }
    });
  }

  // 2. Obtener todos los recibos (Maestro)
  Future<List<Receipt>> getAllReceipts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('receipts');
    return List.generate(maps.length, (i) => Receipt.fromMap(maps[i]));
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

  // 4. Eliminar Recibo (El 'ON DELETE CASCADE' se encarga de los items automáticamente)
  Future<void> deleteReceipt(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
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
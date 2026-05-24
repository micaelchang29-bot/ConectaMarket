import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import '../repositories/database_helper.dart';

class SyncResult {
  final bool success;
  final int movementsSynced;
  final String? error;

  const SyncResult({required this.success, this.movementsSynced = 0, this.error});
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<SyncResult> backup() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return const SyncResult(success: false, error: 'Sin sesión activa.');

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Snapshot de inventario actual
      final products = await db.query('products');

      // 2. Movimientos no sincronizados (con sus items)
      final unsyncedReceipts = await db.query('receipts', where: 'synced = 0');

      final movements = <Map<String, dynamic>>[];
      for (final receipt in unsyncedReceipts) {
        final items = await db.query(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receipt['id']],
        );
        movements.add({
          ...receipt,
          'items': items,
        });
      }

      // 3. Subir a Firestore
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .add({
        'created_at': FieldValue.serverTimestamp(),
        'inventory_snapshot': products,
        'new_movements': movements,
        'movements_count': movements.length,
      });

      // 4. Marcar movimientos como sincronizados
      if (unsyncedReceipts.isNotEmpty) {
        final ids = unsyncedReceipts.map((r) => "'${r['id']}'").join(',');
        await db.rawUpdate('UPDATE receipts SET synced = 1 WHERE id IN ($ids)');
      }

      return SyncResult(success: true, movementsSynced: movements.length);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Retorna cuántos movimientos locales no han sido sincronizados aún.
  Future<int> pendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM receipts WHERE synced = 0');
    return (result.first['cnt'] as int?) ?? 0;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'auth_service.dart';
import 'conexion_service.dart';
import 'product_service.dart';
import 'provider_service.dart';
import 'receipt_service.dart';
import '../repositories/database_helper.dart';
import '../repositories/receipt_repository.dart';
import '../repositories/product_repository.dart';
import '../models/products_model.dart';
import '../utils/mensajes_error.dart';

class SyncResult {
  final bool success;
  final int movementsSynced;
  final DateTime? backupDate;
  final String? error;

  const SyncResult({required this.success, this.movementsSynced = 0, this.backupDate, this.error});
}

class RestoreResult {
  final bool success;
  final int productsRestored;
  final int receiptsRestored;
  final DateTime? backupDate;
  final String? error;

  const RestoreResult({
    required this.success,
    this.productsRestored = 0,
    this.receiptsRestored = 0,
    this.backupDate,
    this.error,
  });
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _timeout = Duration(seconds: 30);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Fecha del último respaldo correcto del usuario actual (null si no hay).
  final ValueNotifier<DateTime?> ultimoRespaldo = ValueNotifier(null);

  static String _clave(String uid) => 'ultimo_respaldo_$uid';

  /// Carga la fecha guardada del último respaldo del usuario [uid].
  Future<void> cargarUltimoRespaldo(String? uid) async {
    if (uid == null) {
      ultimoRespaldo.value = null;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_clave(uid));
      ultimoRespaldo.value = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      ultimoRespaldo.value = null;
    }
  }

  Future<void> _guardarUltimoRespaldo(String uid, DateTime fecha) async {
    ultimoRespaldo.value = fecha;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_clave(uid), fecha.millisecondsSinceEpoch);
    } catch (_) {
      // Si no se puede guardar, la etiqueta solo dura hasta cerrar la app
    }
  }

  /// Sube snapshot completo del inventario + todos los recibos de los últimos [months] meses.
  Future<SyncResult> backup({int months = 6}) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return const SyncResult(success: false, error: 'Inicia sesión para hacer el respaldo.');
    if (!await ConexionService.hayConexion()) {
      return const SyncResult(success: false, error: mensajeSinConexion);
    }

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Snapshot completo de inventario y proveedores
      final products = await db.query('products');
      final providers = await db.query('providers');

      // 2. Todos los recibos del periodo (no solo los no sincronizados)
      final cutoff = DateTime.now().subtract(Duration(days: months * 30));
      final cutoffStr = cutoff.toIso8601String().substring(0, 10);

      final receipts = await db.query(
        'receipts',
        where: "date(fecha) >= date(?)",
        whereArgs: [cutoffStr],
      );

      final movements = <Map<String, dynamic>>[];
      for (final receipt in receipts) {
        final items = await db.query(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receipt['id']],
        );
        movements.add({...receipt, 'items': items});
      }

      // 3. Subir a Firestore. Sin el tiempo límite, Firestore deja la escritura
      // en cola sin conexión y la operación no termina nunca.
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .add({
        'created_at': FieldValue.serverTimestamp(),
        'period_months': months,
        'inventory_snapshot': products,
        'providers': providers,
        'movements': movements,
        'movements_count': movements.length,
      }).timeout(_timeout);

      // 4. Marcar todos los recibos del periodo como sincronizados
      if (receipts.isNotEmpty) {
        final ids = receipts.map((r) => "'${r['id']}'").join(',');
        await db.rawUpdate('UPDATE receipts SET synced = 1 WHERE id IN ($ids)');
      }

      final ahora = DateTime.now();
      await _guardarUltimoRespaldo(user.uid, ahora);
      return SyncResult(success: true, movementsSynced: movements.length, backupDate: ahora);
    } catch (e) {
      return SyncResult(
        success: false,
        error: esErrorDeConexion(e) ? mensajeSinConexion : 'No se pudo completar el respaldo. Inténtalo de nuevo.',
      );
    }
  }

  /// Descarga el backup más reciente y reemplaza los datos locales.
  /// El stock queda tal como estaba al momento del backup (viene en el snapshot).
  Future<RestoreResult> restore() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return const RestoreResult(success: false, error: 'Inicia sesión para restaurar.');
    if (!await ConexionService.hayConexion()) {
      return const RestoreResult(success: false, error: mensajeSinConexion);
    }

    try {
      // 1. Obtener el backup más reciente (del servidor, no de la caché local)
      final query = await _db
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);

      if (query.docs.isEmpty) {
        return const RestoreResult(success: false, error: 'No se encontró ningún backup en la nube.');
      }

      final doc = query.docs.first.data();
      final backupDate = (doc['created_at'] as Timestamp?)?.toDate();
      final List<dynamic> productList = doc['inventory_snapshot'] ?? [];
      final List<dynamic>? providerList = doc['providers'] as List<dynamic>?;
      final List<dynamic> movementList = doc['movements'] ?? [];

      final db = await DatabaseHelper.instance.database;
      final productRepo = ProductRepository();
      final receiptRepo = ReceiptRepository();

      await db.transaction((txn) async {
        // 2. Limpiar datos locales
        await txn.delete('receipt_items');
        await txn.delete('receipts');
        await txn.delete('products');
        // Los respaldos antiguos no traen proveedores: en ese caso se conservan los locales
        if (providerList != null) {
          await txn.delete('providers');
          for (final p in providerList) {
            final map = Map<String, dynamic>.from(p as Map);
            await txn.insert('providers', {
              'id': map['id']?.toString() ?? '',
              'nombre': map['nombre']?.toString() ?? '',
              'ruc': map['ruc']?.toString(),
              'telefono': map['telefono']?.toString(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });

      // 3. Restaurar productos (stock ya correcto en snapshot)
      for (final p in productList) {
        final map = Map<String, dynamic>.from(p as Map);
        await productRepo.upsertProduct(Product(
          id: map['id']?.toString() ?? '',
          nombre: map['nombre']?.toString() ?? '',
          stock: (map['stock'] as num?)?.toDouble() ?? 0,
          umbralAlerta: (map['umbralAlerta'] as num?)?.toInt() ?? 0,
          precio: (map['precio'] as num?)?.toDouble() ?? 0,
        ));
      }

      // 4. Restaurar recibos + items SIN actualizar stock
      for (final m in movementList) {
        final movement = Map<String, dynamic>.from(m as Map);
        final List<dynamic> rawItems = movement.remove('items') ?? [];
        final items = rawItems
            .map((i) => Map<String, dynamic>.from(i as Map))
            .toList();
        // Asegurar que queden marcados como sincronizados
        movement['synced'] = 1;
        await receiptRepo.insertReceiptForRestore(movement, items);
      }

      // 5. Refrescar las pantallas
      await ProductService().refreshProducts();
      await ProviderService().refreshProviders();
      await ReceiptService().refreshReceipts();
      if (backupDate != null) await _guardarUltimoRespaldo(user.uid, backupDate);

      return RestoreResult(
        success: true,
        productsRestored: productList.length,
        receiptsRestored: movementList.length,
        backupDate: backupDate,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        error: esErrorDeConexion(e) ? mensajeSinConexion : 'No se pudo restaurar el respaldo. Inténtalo de nuevo.',
      );
    }
  }

  Future<int> pendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM receipts WHERE synced = 0');
    return (result.first['cnt'] as int?) ?? 0;
  }
}

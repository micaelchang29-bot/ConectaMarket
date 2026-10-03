import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/repositories/product_repository.dart';
import 'package:conectamarket/repositories/provider_repository.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/uid_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// Fuente de uid falsa para inyectar en los repositorios (H5): permite
/// probar el estampado con un uid real sin depender de Firebase/AuthService.
class _FakeUidProvider implements UidProvider {
  @override
  final String? currentUid;
  const _FakeUidProvider(this.currentUid);
}

/// Fase 1: bodega_id se estampa en el alta y se PRESERVA en cada edición
/// posterior. Es la invariante crítica: como el upsert usa REPLACE INTO
/// (reemplaza la fila completa), olvidar reafirmar el valor existente lo
/// dejaría en NULL en cualquier edición hecha sin sesión activa.
void main() {
  late ProductRepository productRepo;
  late ProviderRepository providerRepo;
  late ReceiptRepository receiptRepo;

  setUp(() async {
    await setUpTestDatabase();
    productRepo = ProductRepository();
    providerRepo = ProviderRepository();
    receiptRepo = ReceiptRepository();
  });

  tearDown(tearDownTestDatabase);

  /// Simula una fila que ya fue sincronizada y tiene dueño asignado, sin
  /// pasar por AuthService (los tests no inicializan Firebase).
  Future<void> forzarBodegaId(String tabla, String id, String bodegaId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(tabla, {'bodega_id': bodegaId}, where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> bodegaIdDe(String tabla, String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(tabla, columns: ['bodega_id'], where: 'id = ?', whereArgs: [id]);
    return rows.first['bodega_id'] as String?;
  }

  group('products', () {
    test('un alta sin sesión activa (como en los tests) deja bodega_id en null', () async {
      await productRepo.upsertProduct(
        Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 10, precio: 4.50),
      );
      expect(await bodegaIdDe('products', 'P001'), isNull);
    });

    test('editar un producto ya asignado preserva su bodega_id', () async {
      await productRepo.upsertProduct(Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 10, precio: 4.50));
      await forzarBodegaId('products', 'P001', 'uid-bodega-A');

      // Edición: sube el stock. Sin esta protección, REPLACE INTO borraría
      // bodega_id porque product.toMap() no lo incluye.
      await productRepo.upsertProduct(Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 15, precio: 4.50));

      expect(await bodegaIdDe('products', 'P001'), 'uid-bodega-A');
    });
  });

  group('providers', () {
    test('un alta sin sesión activa deja bodega_id en null', () async {
      await providerRepo.upsertProvider(Provider(id: 'PROV001', nombre: 'Distribuidora Lima'));
      expect(await bodegaIdDe('providers', 'PROV001'), isNull);
    });

    test('editar un proveedor ya asignado preserva su bodega_id', () async {
      await providerRepo.upsertProvider(Provider(id: 'PROV001', nombre: 'Distribuidora Lima'));
      await forzarBodegaId('providers', 'PROV001', 'uid-bodega-A');

      await providerRepo.upsertProvider(Provider(id: 'PROV001', nombre: 'Distribuidora Lima S.A.C.'));

      expect(await bodegaIdDe('providers', 'PROV001'), 'uid-bodega-A');
    });
  });

  group('receipts', () {
    setUp(() async {
      await productRepo.upsertProduct(Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 100, precio: 4.50));
    });

    Receipt reciboDe(double total) => Receipt(id: 'REC001', providerId: null, fecha: '2026-09-28', total: total);
    List<ReceiptItem> itemsDe(double cantidad) => [
          ReceiptItem(id: 'ITEM001', receiptId: 'REC001', productId: 'P001', cantidad: cantidad, costoUnitario: 4.50),
        ];

    test('un alta sin sesión activa deja bodega_id en null', () async {
      await receiptRepo.saveFullReceipt(reciboDe(22.50), itemsDe(5));
      expect(await bodegaIdDe('receipts', 'REC001'), isNull);
    });

    test('re-guardar el mismo recibo preserva su bodega_id', () async {
      await receiptRepo.saveFullReceipt(reciboDe(22.50), itemsDe(5));
      await forzarBodegaId('receipts', 'REC001', 'uid-bodega-A');

      // Mismo id de recibo, mismo id de item: upsert sobre la cabecera.
      await receiptRepo.saveFullReceipt(reciboDe(22.50), itemsDe(5));

      expect(await bodegaIdDe('receipts', 'REC001'), 'uid-bodega-A');
    });
  });

  group('H5 - alta con un uid real inyectado (no el fallback a null)', () {
    test('products: la fila queda estampada con el uid inyectado', () async {
      final repo = ProductRepository(uidProvider: const _FakeUidProvider('uid-real-123'));
      await repo.upsertProduct(Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 10, precio: 4.50));

      expect(await bodegaIdDe('products', 'P001'), 'uid-real-123');
    });

    test('providers: la fila queda estampada con el uid inyectado', () async {
      final repo = ProviderRepository(uidProvider: const _FakeUidProvider('uid-real-123'));
      await repo.upsertProvider(Provider(id: 'PROV001', nombre: 'Distribuidora Lima'));

      expect(await bodegaIdDe('providers', 'PROV001'), 'uid-real-123');
    });

    test('receipts: la fila queda estampada con el uid inyectado', () async {
      await productRepo.upsertProduct(Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 100, precio: 4.50));

      final repo = ReceiptRepository(uidProvider: const _FakeUidProvider('uid-real-123'));
      await repo.saveFullReceipt(
        Receipt(id: 'REC001', providerId: null, fecha: '2026-09-28', total: 22.50),
        [ReceiptItem(id: 'ITEM001', receiptId: 'REC001', productId: 'P001', cantidad: 5, costoUnitario: 4.50)],
      );

      expect(await bodegaIdDe('receipts', 'REC001'), 'uid-real-123');
    });

    test('la rama de fallback a null (sin uidProvider inyectado) sigue sin cambios', () async {
      // Mismo repo sin inyectar nada, como en los tests de arriba: confirma
      // que agregar la inyección no modificó el comportamiento por defecto.
      await productRepo.upsertProduct(Product(id: 'P002', nombre: 'Gaseosa Inca Kola 500ml', stock: 24, precio: 3.50));
      expect(await bodegaIdDe('products', 'P002'), isNull);
    });
  });

  group('H2 - insertReceiptForRestore estampa bodega_id', () {
    late ReceiptRepository repoConSesionA;

    setUp(() {
      repoConSesionA = ReceiptRepository(uidProvider: const _FakeUidProvider('uid-sesion-A'));
    });

    test('un recibo nuevo restaurado se estampa con la sesión que restaura, no con un valor previo', () async {
      await repoConSesionA.insertReceiptForRestore(
        {
          'id': 'REC-RESTORE-1',
          'provider_id': null,
          'fecha': '2026-09-01',
          'total': 10.0,
          'tipomovimiento': 0,
          'synced': 1,
          'serie': 'B001',
        },
        [],
      );

      expect(await bodegaIdDe('receipts', 'REC-RESTORE-1'), 'uid-sesion-A');
    });

    test(
      'reproduce el bug de H2: un backup v6+ trae bodega_id de OTRA cuenta embebido en el map -> '
      'se descarta y queda con el uid de quien restaura',
      () async {
        // Simula un backup tomado desde una base v6+ (db.query trae todas
        // las columnas, incluida bodega_id de la cuenta que subió el backup).
        await repoConSesionA.insertReceiptForRestore(
          {
            'id': 'REC-RESTORE-2',
            'provider_id': null,
            'fecha': '2026-09-01',
            'total': 10.0,
            'tipomovimiento': 0,
            'synced': 1,
            'serie': 'B001',
            'bodega_id': 'uid-cuenta-B', // dueño original del backup en la nube
          },
          [],
        );

        // Antes del fix, esto habría quedado en 'uid-cuenta-B' (el valor
        // embebido), dejando el recibo con un dueño ajeno a quien restauró.
        expect(await bodegaIdDe('receipts', 'REC-RESTORE-2'), 'uid-sesion-A');
      },
    );

    test('restaurar sobre un recibo que ya existía localmente preserva su bodega_id (edición, no alta)', () async {
      // Ya existe localmente, asignado a otra bodega (p. ej. sobrevivió a un
      // restore anterior). Un segundo restore no debe robarle el dueño.
      await repoConSesionA.insertReceiptForRestore(
        {
          'id': 'REC-RESTORE-3',
          'provider_id': null,
          'fecha': '2026-09-01',
          'total': 10.0,
          'tipomovimiento': 0,
        },
        [],
      );
      await forzarBodegaId('receipts', 'REC-RESTORE-3', 'uid-dueno-original');

      await repoConSesionA.insertReceiptForRestore(
        {
          'id': 'REC-RESTORE-3',
          'provider_id': null,
          'fecha': '2026-09-01',
          'total': 10.0,
          'tipomovimiento': 0,
        },
        [],
      );

      expect(await bodegaIdDe('receipts', 'REC-RESTORE-3'), 'uid-dueno-original');
    });

    test(
      'restaurar con la MISMA sesión que subió el backup (bodega_id embebido = currentUid) '
      'sigue funcionando igual que antes del fix, items incluidos',
      () async {
        await productRepo.upsertProduct(Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 100, precio: 4.50));

        await repoConSesionA.insertReceiptForRestore(
          {
            'id': 'REC-RESTORE-4',
            'provider_id': null,
            'fecha': '2026-09-01',
            'total': 22.50,
            'tipomovimiento': 0,
            'synced': 1,
            'serie': 'B001',
            'bodega_id': 'uid-sesion-A', // el mismo uid que la sesión que restaura
          },
          [
            {'id': 'ITEM-RESTORE-4', 'receipt_id': 'REC-RESTORE-4', 'product_id': 'P001', 'cantidad': 5.0, 'costoUnitario': 4.50},
          ],
        );

        // El resultado es el mismo que antes del fix: el valor embebido ya
        // coincidía con la sesión, no hay nada que corregir.
        expect(await bodegaIdDe('receipts', 'REC-RESTORE-4'), 'uid-sesion-A');

        // El fix de H2 solo toca la cabecera: los items se insertan igual
        // que siempre.
        final db = await DatabaseHelper.instance.database;
        final items = await db.query('receipt_items', where: 'receipt_id = ?', whereArgs: ['REC-RESTORE-4']);
        expect(items, hasLength(1));
        expect(items.first['product_id'], 'P001');
        expect(items.first['cantidad'], 5.0);

        // El resto de los campos de la cabecera tambien se preserva intacto.
        final receiptRows = await db.query('receipts', where: 'id = ?', whereArgs: ['REC-RESTORE-4']);
        expect(receiptRows.first['total'], 22.50);
        expect(receiptRows.first['serie'], 'B001');
      },
    );
  });
}

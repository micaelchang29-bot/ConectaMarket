import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/repositories/product_repository.dart';
import 'package:conectamarket/repositories/provider_repository.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

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
}

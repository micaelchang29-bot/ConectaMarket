import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/product_repository.dart';
import 'package:conectamarket/repositories/provider_repository.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:conectamarket/services/provider_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// PB-04-2 / CP008: no se puede eliminar un producto o proveedor que ya tiene
/// movimientos registrados.
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

  /// Registra una compra del producto [productId] al proveedor [providerId].
  Future<void> registrarCompra({required String productId, String? providerId}) async {
    final receipt = Receipt(
      id: 'REC-001',
      providerId: providerId,
      fecha: '2026-09-28',
      total: 38.00,
      tipomovimiento: true,
    );
    await receiptRepo.saveFullReceipt(receipt, [
      ReceiptItem(
        id: 'ITEM-001',
        receiptId: receipt.id,
        productId: productId,
        cantidad: 10,
        costoUnitario: 3.80,
      ),
    ]);
  }

  Future<bool> existeProducto(String id) async =>
      (await productRepo.getAllProducts()).any((p) => p.id == id);

  Future<bool> existeProveedor(String id) async =>
      (await providerRepo.getProviderById(id)) != null;

  group('productos', () {
    setUp(() async {
      await productRepo.upsertProduct(
        Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 10, umbralAlerta: 5, precio: 4.50),
      );
    });

    test('un producto con movimientos no se puede eliminar', () async {
      await registrarCompra(productId: 'P001');

      await expectLater(
        ProductService().deleteProduct('P001'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('No se puede eliminar el producto'),
        )),
      );

      expect(await existeProducto('P001'), isTrue);
    });

    test('un producto sin movimientos se elimina', () async {
      await ProductService().deleteProduct('P001');
      expect(await existeProducto('P001'), isFalse);
    });
  });

  group('proveedores', () {
    setUp(() async {
      await providerRepo.upsertProvider(
        Provider(id: 'PROV001', nombre: 'Distribuidora Lima', ruc: '20123456789', telefono: '987654321'),
      );
      await productRepo.upsertProduct(
        Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 10, umbralAlerta: 5, precio: 4.50),
      );
    });

    test('un proveedor con recibos no se puede eliminar', () async {
      await registrarCompra(productId: 'P001', providerId: 'PROV001');

      await expectLater(
        ProviderService().removeProvider('PROV001'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('No se puede eliminar el proveedor'),
        )),
      );

      expect(await existeProveedor('PROV001'), isTrue);
    });

    test('un proveedor sin recibos se elimina', () async {
      await ProviderService().removeProvider('PROV001');
      expect(await existeProveedor('PROV001'), isFalse);
    });
  });
}

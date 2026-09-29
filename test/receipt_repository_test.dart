import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/product_repository.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// PB-02-2 / CP004: el registro de una venta nunca debe dejar el stock negativo.
void main() {
  late ProductRepository productRepo;
  late ReceiptRepository receiptRepo;

  setUp(() async {
    await setUpTestDatabase();
    productRepo = ProductRepository();
    receiptRepo = ReceiptRepository();

    await productRepo.upsertProduct(
      Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 10, umbralAlerta: 5, precio: 4.50),
    );
  });

  tearDown(tearDownTestDatabase);

  Receipt venta({double total = 0}) => Receipt(
        id: 'REC-VENTA',
        providerId: null,
        fecha: '2026-09-28',
        total: total,
        tipomovimiento: false,
      );

  Receipt compra({double total = 0}) => Receipt(
        id: 'REC-COMPRA',
        providerId: null,
        fecha: '2026-09-28',
        total: total,
        tipomovimiento: true,
      );

  ReceiptItem item(String receiptId, double cantidad) => ReceiptItem(
        id: 'ITEM-$receiptId',
        receiptId: receiptId,
        productId: 'P001',
        cantidad: cantidad,
        costoUnitario: 3.80,
      );

  Future<double> stockActual() async {
    final products = await productRepo.getAllProducts();
    return products.firstWhere((p) => p.id == 'P001').stock;
  }

  test('una venta mayor al stock disponible se rechaza y no altera nada', () async {
    final r = venta(total: 67.50);

    expect(
      () => receiptRepo.saveFullReceipt(r, [item(r.id, 15)]),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('Stock insuficiente'),
        ),
      ),
    );

    // La transacción se revierte completa: el stock sigue igual y no hay recibo.
    await expectLater(stockActual(), completion(10));
    expect(await receiptRepo.getAllReceipts(), isEmpty);
  });

  test('una venta dentro del stock disponible lo descuenta', () async {
    final r = venta(total: 22.50);
    await receiptRepo.saveFullReceipt(r, [item(r.id, 5)]);

    expect(await stockActual(), 5);
    expect((await receiptRepo.getAllReceipts()).length, 1);
  });

  test('una compra incrementa el stock', () async {
    final r = compra(total: 19.00);
    await receiptRepo.saveFullReceipt(r, [item(r.id, 5)]);

    expect(await stockActual(), 15);
  });

  test('una venta que deja el stock exactamente en 0 es válida', () async {
    final r = venta(total: 45.00);
    await receiptRepo.saveFullReceipt(r, [item(r.id, 10)]);

    expect(await stockActual(), 0);
  });
}

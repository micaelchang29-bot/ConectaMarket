import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/repositories/product_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// PB-01-1 / CP001: el producto tiene precio de venta obligatorio y mayor a 0.
void main() {
  group('persistencia del precio', () {
    late ProductRepository productRepo;

    setUp(() async {
      await setUpTestDatabase();
      productRepo = ProductRepository();
    });

    tearDown(tearDownTestDatabase);

    test('un producto con precio 3.50 se guarda y se lee con ese precio', () async {
      await ProductService().saveProduct(
        Product(id: 'P001', nombre: 'Gaseosa Inca Kola 500ml', stock: 24, umbralAlerta: 6, precio: 3.50),
      );

      final guardado = (await productRepo.getAllProducts()).firstWhere((p) => p.id == 'P001');
      expect(guardado.precio, 3.50);
      expect(guardado.stock, 24);
    });

    test('un precio en 0 se rechaza', () async {
      await expectLater(
        ProductService().saveProduct(Product(id: 'P002', nombre: 'Pan francés', stock: 50, precio: 0)),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('El precio de venta debe ser mayor a 0'),
        )),
      );

      expect(await productRepo.getAllProducts(), isEmpty);
    });

    test('un precio negativo se rechaza', () async {
      await expectLater(
        ProductService().saveProduct(Product(id: 'P003', nombre: 'Leche Gloria', stock: 12, precio: -1.20)),
        throwsA(isA<Exception>()),
      );

      expect(await productRepo.getAllProducts(), isEmpty);
    });
  });

  group('Product.toMap / fromMap', () {
    test('el precio va y vuelve del mapa', () {
      final original = Product(id: 'P001', nombre: 'Aceite Primor 1L', stock: 8, umbralAlerta: 3, precio: 12.90);
      final map = original.toMap();

      expect(map['precio'], 12.90);

      final recuperado = Product.fromMap(map);
      expect(recuperado.precio, 12.90);
      expect(recuperado.nombre, 'Aceite Primor 1L');
      expect(recuperado.stock, 8);
      expect(recuperado.umbralAlerta, 3);
    });

    test('un registro sin precio (base anterior a la versión 5) queda en 0', () {
      final recuperado = Product.fromMap({
        'id': 'P001',
        'nombre': 'Fideos Don Vittorio',
        'stock': 10,
        'umbralAlerta': 5,
      });

      expect(recuperado.precio, 0);
    });

    test('un stock entero de SQLite se normaliza a double sin romper el cast', () {
      final recuperado = Product.fromMap({
        'id': 'P001',
        'nombre': 'Atún Florida',
        'stock': 7, // int, como lo devuelve SQLite cuando el valor es entero
        'umbralAlerta': 5,
        'precio': 5,
      });

      expect(recuperado.stock, 7.0);
      expect(recuperado.precio, 5.0);
    });
  });
}

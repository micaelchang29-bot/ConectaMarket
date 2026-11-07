import 'package:conectamarket/screens/products_list_screen.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('El catálogo vacío guía para agregar el primer producto (0002193)', (tester) async {
    await tester.runAsync(() async {
      await abrirBaseDePrueba();
      await ProductService().refreshProducts();
    });

    await tester.pumpWidget(MaterialApp(home: CatalogScreen()));
    await tester.pump();

    expect(find.text('Aún no tienes productos. Toca + para agregar el primero.'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.runAsync(() async {
      await crearProducto('ARZ1', 'Arroz Costeño 1kg', stock: 50, precio: 4.5);
    });
    await tester.pump();

    expect(find.text('Arroz Costeño 1kg'), findsOneWidget);
    expect(find.text('SKU: ARZ1 · S/ 4.50'), findsOneWidget);

    await tester.runAsync(cerrarBaseDePrueba);
  });
}

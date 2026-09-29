import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/screens/product_details_screen.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// CP001: el formulario de producto exige un precio de venta mayor a 0.
///
/// Solo se verifica la capa de UI: estas pruebas no consultan SQLite, porque
/// dentro de `testWidgets` el reloj es simulado y un await real a la base nunca
/// se resolveria. La persistencia se cubre en product_price_test.dart.
void main() {
  // La base temporal evita que el ProductService intente abrir la base real del
  // dispositivo. Se prepara una sola vez para todo el archivo y el singleton se
  // construye aqui: asi su refresco inicial (asincrono) termina antes de
  // entrar al reloj simulado de las pruebas y no deja trabajo pendiente.
  setUpAll(() async {
    await setUpTestDatabase();
    await ProductService().refreshProducts();
  });
  tearDownAll(tearDownTestDatabase);

  Future<void> abrirFormulario(WidgetTester tester, {Product? product}) async {
    await tester.pumpWidget(MaterialApp(home: ProductDetailsScreen(product: product)));
    await tester.pump();
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('el formulario muestra el campo de precio de venta', (tester) async {
    await abrirFormulario(tester);
    expect(find.text('Precio de venta (S/)'), findsOneWidget);
  });

  testWidgets('guardar sin precio muestra "Campo obligatorio"', (tester) async {
    await abrirFormulario(tester);

    await tester.enterText(campo('SKU o Código (ID)'), 'P001');
    await tester.enterText(campo('Nombre del Producto'), 'Arroz Costeño 1kg');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pump();

    // El precio quedó vacío: el formulario no pasa la validación.
    expect(find.text('Campo obligatorio'), findsWidgets);
  });

  testWidgets('un precio en 0 muestra "Ingrese un precio mayor a 0"', (tester) async {
    await abrirFormulario(tester);

    await tester.enterText(campo('SKU o Código (ID)'), 'P001');
    await tester.enterText(campo('Nombre del Producto'), 'Arroz Costeño 1kg');
    await tester.enterText(campo('Precio de venta (S/)'), '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pump();

    expect(find.text('Ingrese un precio mayor a 0'), findsOneWidget);
  });

  testWidgets('un precio negativo también se rechaza', (tester) async {
    await abrirFormulario(tester);

    await tester.enterText(campo('SKU o Código (ID)'), 'P001');
    await tester.enterText(campo('Nombre del Producto'), 'Arroz Costeño 1kg');
    await tester.enterText(campo('Precio de venta (S/)'), '-3.50');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pump();

    expect(find.text('Ingrese un precio mayor a 0'), findsOneWidget);
  });

  testWidgets('al editar, el precio guardado se precarga en el campo', (tester) async {
    await abrirFormulario(
      tester,
      product: Product(id: 'P001', nombre: 'Arroz Costeño 1kg', stock: 24, umbralAlerta: 5, precio: 4.50),
    );

    expect(find.text('4.50'), findsOneWidget);
  });
}

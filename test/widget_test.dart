// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:conectamarket/main.dart'; // O donde tengas tu app

void main() {
  testWidgets('La App inicia y carga el catálogo', (WidgetTester tester) async {
    // Construimos la app
    await tester.pumpWidget(const ConectaMarketApp());
    await tester.pumpAndSettle(); // Espera a que las animaciones de navegación terminen

    // Verificamos que el título del catálogo aparezca
    expect(find.text('Catálogo'), findsOneWidget);
  });
}
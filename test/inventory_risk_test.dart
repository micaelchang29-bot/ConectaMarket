import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/repositories/product_repository.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/dashboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// PB-09-2 / CP018: el nivel de riesgo se recalcula a partir del stock actual y
/// de la demanda proyectada, así que bajar el stock debe subir el nivel.
///
/// Reglas de clasificación (cobertura en días):
///   > 15 BAJO | 8-15 MEDIO | 4-7 ALTO | < 4 CRÍTICO
void main() {
  const String productId = 'P001';
  const double ventaDiaria = 5;

  late ProductRepository productRepo;
  late ReceiptRepository receiptRepo;
  late DashboardAiService dashboard;

  setUp(() async {
    await setUpTestDatabase();
    productRepo = ProductRepository();
    receiptRepo = ReceiptRepository();
    dashboard = DashboardAiService();

    await productRepo.upsertProduct(
      Product(id: productId, nombre: 'Arroz Costeño 1kg', stock: 0, umbralAlerta: 5, precio: 4.50),
    );

    // 20 días consecutivos de ventas estables: por encima del mínimo de 17 días
    // que exige el clasificador, y con tendencia 0 para que Holt proyecte
    // exactamente la misma demanda diaria.
    final base = DateTime(2026, 9, 1);
    for (int i = 0; i < 20; i++) {
      final fecha = base.add(Duration(days: i)).toIso8601String().substring(0, 10);
      // Se insertan sin pasar por el stock: el stock de cada escenario se fija
      // aparte, para poder probar varios niveles sobre el mismo histórico.
      await receiptRepo.insertReceiptForRestore(
        {
          'id': 'REC-$i',
          'provider_id': null,
          'fecha': fecha,
          'total': ventaDiaria * 4.50,
          'tipomovimiento': 0,
          'synced': 1,
          'serie': 'B001',
        },
        [
          {
            'id': 'ITEM-$i',
            'receipt_id': 'REC-$i',
            'product_id': productId,
            'cantidad': ventaDiaria,
            'costoUnitario': 4.50,
          },
        ],
      );
    }
  });

  tearDown(tearDownTestDatabase);

  /// Fija el stock del producto y devuelve su clasificación de riesgo.
  Future<Map<String, dynamic>> clasificarCon(double stock) async {
    await productRepo.upsertProduct(
      Product(id: productId, nombre: 'Arroz Costeño 1kg', stock: stock, umbralAlerta: 5, precio: 4.50),
    );

    final resultados = await dashboard.getInventoryRiskClassification();
    expect(resultados, isNotEmpty, reason: 'el producto debe ser predecible con 20 días de histórico');
    return resultados.firstWhere((r) => r['id'] == productId);
  }

  test('la demanda diaria proyectada coincide con las ventas estables', () async {
    final metrica = await clasificarCon(200);
    expect((metrica['avg_daily_qty'] as num).toDouble(), closeTo(ventaDiaria, 0.001));
  });

  test('stock alto (200 u. = 40 días de cobertura) da riesgo BAJO', () async {
    final metrica = await clasificarCon(200);

    expect(metrica['rotation_days'], 40);
    expect(metrica['risk_level'], 'BAJO');
    expect(metrica['suggested_qty'], 0);
  });

  test('al bajar el stock a 25 u. (5 días) el nivel pasa a ALTO', () async {
    expect((await clasificarCon(200))['risk_level'], 'BAJO');

    final metrica = await clasificarCon(25);
    expect(metrica['rotation_days'], 5);
    expect(metrica['risk_level'], 'ALTO');
    // Reposición sugerida para cubrir 30 días: (30 - 5) * 5 = 125 u.
    expect(metrica['suggested_qty'], 125);
  });

  test('50 u. (10 días) da riesgo MEDIO y 15 u. (3 días) CRÍTICO', () async {
    expect((await clasificarCon(50))['risk_level'], 'MEDIO');
    expect((await clasificarCon(15))['risk_level'], 'CRÍTICO');
  });

  test('un producto sin histórico suficiente no se clasifica', () async {
    await productRepo.upsertProduct(
      Product(id: 'P002', nombre: 'Producto nuevo', stock: 10, umbralAlerta: 5, precio: 2.00),
    );

    final resultados = await dashboard.getInventoryRiskClassification();
    expect(resultados.any((r) => r['id'] == 'P002'), isFalse);
  });
}

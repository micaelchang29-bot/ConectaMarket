import 'dart:math';
import '../repositories/dashboard_repository.dart';
import 'provider_service.dart';

class DashboardAiService {
  final DashboardRepository _dashboardRepo = DashboardRepository();
  final ProviderService _providerService = ProviderService();

  // ==========================================================
  // 1. MOTOR PRESCRIPTIVO (LÓGICA DE NEGOCIO PURA)
  // ==========================================================
  Future<Map<String, dynamic>> getInventoryInsight() async {
    // Llamada limpia al repositorio sin queries incrustadas
    final List<Map<String, dynamic>> criticalProducts = 
        await _dashboardRepo.getRawCriticalProducts();

    if (criticalProducts.isEmpty) {
      return {
        'critical_count': 0,
        'prescription': 'Inventario estable. No se detectan quiebres de stock proyectados.',
        'suggested_provider': null,
      };
    }

    final targetProduct = criticalProducts.first;
    final String productId = targetProduct['id'];
    final String productName = targetProduct['nombre'];

    final providerRecommendation = await _providerService.getBestProviderForProduct(productId);

    if (providerRecommendation != null) {
      return {
        'critical_count': criticalProducts.length,
        'prescription': '¡Alerta de quiebre! Reabastecer "$productName". El modelo prescribe comprar a este proveedor para maximizar tu margen de ganancia.',
        'suggested_provider': providerRecommendation['provider_name'],
        'estimated_cost': providerRecommendation['estimated_cost'],
      };
    }

    return {
      'critical_count': criticalProducts.length,
      'prescription': 'Tienes ${criticalProducts.length} productos con stock bajo. Registra más compras para activar la prescripción de proveedores.',
      'suggested_provider': null,
    };
  }

  // ==========================================================
  // 4. MOTOR DE ALERTAS DE STOCK (LISTA DINÁMICA)
  // ==========================================================
  Future<List<Map<String, dynamic>>> getLowStockAlerts() async {
    try {
      final lowStockProducts = await _dashboardRepo.getLowStockProducts();
      return lowStockProducts;
    } catch (e) {
      print('Error en getLowStockAlerts: $e');
      return [];
    }
  }

  // ==========================================================
  // 2. MOTOR PREDICTIVO (MODELO MATEMÁTICO PURO)
  // ==========================================================
  Future<List<double>> predictWeeklyDemand(String productId) async {
    // El repositorio se encarga de la Query e I/O de disco
    final List<Map<String, dynamic>> salesHistory = 
        await _dashboardRepo.getRawSalesHistory(productId);

    if (salesHistory.length < 3) {
      return [2.0, 2.0, 3.0, 2.0, 4.0, 3.0, 5.0, 2.0, 3.0, 2.0, 4.0, 3.0, 2.0, 3.0]; // Baseline estática
    }

    final List<double> historicalData = salesHistory.map((row) => (row['total_qty'] as num).toDouble()).toList();
    return _runHolt(historicalData, 14);
  }

  // ==========================================================
  // 3. MOTOR DE INSIGHTS DE PRODUCTOS (ANALÍTICA)
  // ==========================================================
  Future<Map<String, dynamic>> getProductInsights() async {
    try {
      final mostSold = await _dashboardRepo.getMostSoldProduct();
      final mostProfitable = await _dashboardRepo.getMostProfitableProduct();

      return {
        'most_sold': mostSold ?? {},
        'most_profitable': mostProfitable ?? {},
        'error': null,
      };
    } catch (e) {
      print('Error en getProductInsights: $e');
      return {
        'most_sold': {},
        'most_profitable': {},
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getLastMonthProductInsights() async {
    try {
      final now = DateTime.now();
      final lastMonth = now.month == 1 ? 12 : now.month - 1;
      final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;

      final mostSold = await _dashboardRepo.getMostSoldProductByMonth(lastMonthYear, lastMonth);
      final mostProfitable = await _dashboardRepo.getMostProfitableProductByMonth(lastMonthYear, lastMonth);

      return {
        'most_sold': mostSold ?? {},
        'most_profitable': mostProfitable ?? {},
        'error': null,
      };
    } catch (e) {
      print('Error en getLastMonthProductInsights: $e');
      return {
        'most_sold': {},
        'most_profitable': {},
        'error': e.toString(),
      };
    }
  }

  // ==========================================================
  // 5. MOTOR DE MOVIMIENTOS RECIENTES
  // ==========================================================
  Future<List<Map<String, dynamic>>> getRecentMovements() async {
    try {
      final movements = await _dashboardRepo.getRecentMovements();
      return movements;
    } catch (e) {
      print('Error en getRecentMovements: $e');
      return [];
    }
  }

  // ==========================================================
  // 6. ML PAIR 1: CLASIFICACIÓN DE RIESGO DE INVENTARIO (HOLT-DRIVEN)
  // Solo incluye los productos predecibles (historial >= 17 días de venta),
  // mismo umbral que validateForecastAccuracy. Los demás se omiten.
  // ==========================================================
  Future<List<Map<String, dynamic>>> getInventoryRiskClassification() async {
    try {
      final products = await _dashboardRepo.getAllProductsWithStock();
      final List<Map<String, dynamic>> results = [];

      for (final product in products) {
        final String productId = product['id'] as String;
        final double stock = (product['stock'] as num?)?.toDouble() ?? 0.0;

        final history = await _dashboardRepo.getRawSalesHistory(productId);
        if (history.length < 17) continue; // no predecible, misma regla que validación

        final List<double> historicalData =
            history.map((r) => (r['total_qty'] as num).toDouble()).toList();
        final List<double> forecast = _runHolt(historicalData, 14);

        final double avgPredictedDaily =
            forecast.isNotEmpty ? forecast.reduce((a, b) => a + b) / forecast.length : 1.0;
        final double rotationDays =
            avgPredictedDaily > 0 ? stock / avgPredictedDaily : 9999.0;

        final String riskLevel;
        final int riskScore;
        if (rotationDays > 15) {
          riskLevel = 'BAJO';
          riskScore = 0;
        } else if (rotationDays >= 8) {
          riskLevel = 'MEDIO';
          riskScore = 1;
        } else if (rotationDays >= 4) {
          riskLevel = 'ALTO';
          riskScore = 2;
        } else {
          riskLevel = 'CRÍTICO';
          riskScore = 3;
        }

        final int suggestedQty = riskLevel == 'BAJO'
            ? 0
            : ((30 - rotationDays) * avgPredictedDaily).ceil().clamp(0, 99999);

        results.add({
          'id': productId,
          'nombre': product['nombre'],
          'stock': stock,
          'umbralAlerta': product['umbralAlerta'],
          'avg_daily_qty': avgPredictedDaily,
          'rotation_days': rotationDays.toInt(),
          'risk_level': riskLevel,
          'risk_score': riskScore,
          'suggested_qty': suggestedQty,
        });
      }

      results.sort((a, b) {
        final int scoreCmp = (b['risk_score'] as int).compareTo(a['risk_score'] as int);
        if (scoreCmp != 0) return scoreCmp;
        return (a['rotation_days'] as int).compareTo(b['rotation_days'] as int);
      });

      return results;
    } catch (e) {
      print('Error en getInventoryRiskClassification: $e');
      return [];
    }
  }

  // ==========================================================
  // 7. ML PAIR PROVIDERS: RANKING Y SCORE DE CONFIABILIDAD
  // ==========================================================
  Future<List<Map<String, dynamic>>> getProviderRanking() async {
    try {
      return await _dashboardRepo.getProviderRanking();
    } catch (e) {
      print('Error en getProviderRanking: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProvidersForProduct(String productId) async {
    try {
      return await _dashboardRepo.getProvidersForProduct(productId);
    } catch (e) {
      print('Error en getProvidersForProduct: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRecommendedProvider(String productId) async {
    try {
      final providers = await _dashboardRepo.getProvidersForProduct(productId);
      return providers.isNotEmpty ? providers.first : null;
    } catch (e) {
      print('Error en getRecommendedProvider: $e');
      return null;
    }
  }

  // ==========================================================
  // 8. VALIDACIÓN DEL MODELO (MAPE con train/test split)
  // ==========================================================
  List<double> _runHolt(List<double> data, int horizon,
      {double alpha = 0.1, double beta = 0.1, double phi = 0.7}) {
    double level = data[0];
    double trend = data[1] - data[0];

    for (int i = 1; i < data.length; i++) {
      final double lastLevel = level;
      level = (alpha * data[i]) + ((1 - alpha) * (level + phi * trend));
      trend = (beta * (level - lastLevel)) + ((1 - beta) * phi * trend);
    }

    // forecast(h) = level + (phi + phi² + ... + phi^h) * trend
    return List.generate(horizon, (h) {
      double phiSum = 0;
      double phiPow = phi;
      for (int i = 0; i <= h; i++) {
        phiSum += phiPow;
        phiPow *= phi;
      }
      return max(0.0, level + phiSum * trend);
    });
  }

  Future<Map<String, dynamic>> validateForecastAccuracy() async {
    final stopwatch = Stopwatch()..start();
    final products = await _dashboardRepo.getAllProducts();

    final List<Map<String, dynamic>> productResults = [];
    final List<double> allMapes = [];

    for (final product in products) {
      final String productId = product['id'] as String;
      final String productName = product['nombre'] as String;

      final history = await _dashboardRepo.getRawSalesHistory(productId);
      if (history.length < 17) continue;

      final trainHistory = history.sublist(0, history.length - 14);
      if (trainHistory.isEmpty) continue;

      final DateTime lastTrainDate = DateTime.parse(trainHistory.last['date'] as String);
      final DateTime windowStart = lastTrainDate.subtract(const Duration(days: 41));
      final List<Map<String, dynamic>> windowRows = trainHistory
          .where((r) => !DateTime.parse(r['date'] as String).isBefore(windowStart))
          .toList();
      final int saleDaysInWindow = windowRows.length;
      if (saleDaysInWindow < 17) continue;

      // Syntetos-Boylan: mismo criterio que el pipeline de refinamiento
      final double totalQtyWindow = windowRows.fold(0.0, (s, r) => s + (r['total_qty'] as num).toDouble());
      final double adi = 42.0 / saleDaysInWindow;
      final List<double> qtys = windowRows.map((r) => (r['total_qty'] as num).toDouble()).toList();
      final double meanQty = totalQtyWindow / qtys.length;
      double cv2 = 0;
      if (meanQty > 0 && qtys.length > 1) {
        final double variance = qtys.map((q) => (q - meanQty) * (q - meanQty)).reduce((a, b) => a + b) / qtys.length;
        cv2 = variance / (meanQty * meanQty);
      }
      if (adi >= 1.32 || cv2 >= 0.49) continue;

      final String clasificacion = saleDaysInWindow >= 42 ? 'predecible' : 'poco_frecuente';

      final fullData = history.map((r) => (r['total_qty'] as num).toDouble()).toList();
      final trainData = fullData.sublist(0, fullData.length - 14);
      final testData = fullData.sublist(fullData.length - 14);

      final predictions = _runHolt(trainData, 14);

      final double totalReal = testData.reduce((a, b) => a + b);
      if (totalReal == 0) continue;

      final double totalPred = predictions.reduce((a, b) => a + b);
      final double mape = ((totalReal - totalPred).abs() / totalReal) * 100;

      allMapes.add(mape);
      productResults.add({
        'nombre': productName,
        'mape': mape,
        'real': totalReal,
        'pred': totalPred,
        'clasificacion': clasificacion,
        'sale_days_window': saleDaysInWindow,
      });
    }

    stopwatch.stop();

    final double globalMape = allMapes.isEmpty
        ? 0.0
        : allMapes.reduce((a, b) => a + b) / allMapes.length;

    return {
      'global_mape': globalMape,
      'latency_ms': stopwatch.elapsedMilliseconds,
      'productos_evaluados': productResults.length,
      'detalle': productResults,
    };
  }

}
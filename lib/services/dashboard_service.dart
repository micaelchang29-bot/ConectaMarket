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
      return [2.0, 2.0, 3.0, 2.0, 4.0, 3.0, 5.0]; // Baseline estática
    }

    // El servicio procesa el vector numérico puro en RAM
    List<double> historicalData = salesHistory.map((row) => (row['total_qty'] as num).toDouble()).toList();

    // --- ALGORITMO Holt: Inferencia en el Borde ---
    double alpha = 0.4;
    double beta = 0.3;
    double level = historicalData[0];
    double trend = historicalData[1] - historicalData[0];

    for (int i = 1; i < historicalData.length; i++) {
      double lastLevel = level;
      level = (alpha * historicalData[i]) + ((1 - alpha) * (level + trend));
      trend = (beta * (level - lastLevel)) + ((1 - beta) * trend);
    }

    List<double> predictions = [];
    for (int horizon = 1; horizon <= 7; horizon++) {
      double projectedDemand = level + (trend * horizon);
      predictions.add(max(0.0, double.parse(projectedDemand.toStringAsFixed(1))));
    }

    return predictions;
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
  // 6. ML PAIR 1: CLASIFICACIÓN DE RIESGO DE INVENTARIO
  // ==========================================================
  Future<List<Map<String, dynamic>>> getInventoryRiskClassification() async {
    try {
      final riskMetrics = await _dashboardRepo.getInventoryRiskMetrics();
      return riskMetrics;
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
}
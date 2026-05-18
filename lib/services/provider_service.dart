import 'dart:async';
import '../models/providers_model.dart';
import '../repositories/provider_repository.dart';
import 'dart:math';

class ProviderService {
  static final ProviderService _instance = ProviderService._internal();

  factory ProviderService() {
    return _instance;
  }

  final ProviderRepository _repo = ProviderRepository();
  
  // Caché en memoria RAM
  List<Provider> _cachedProviders = [];
  List<Provider> get cachedProviders => _cachedProviders;
  
  // Stream para notificar cambios en la lista de proveedores a la UI
  final _providerController = StreamController<List<Provider>>.broadcast();
  Stream<List<Provider>> get providerStream => _providerController.stream;

  ProviderService._internal() {
    refreshProviders();
  }

  Future<void> refreshProviders() async {
    final providers = await _repo.getAllProviders();
    _cachedProviders = providers;
    _providerController.add(providers);
  }

  // Lógica de negocio: Validar RUC (11 dígitos) antes de guardar
  Future<void> saveProvider(Provider provider) async {
    if (provider.ruc != null && provider.ruc!.length != 11) {
      throw Exception("El RUC debe tener exactamente 11 dígitos");
    }
    
    await _repo.upsertProvider(provider);
    await refreshProviders(); // Actualizar UI tras el cambio
  }

  // Lógica de negocio: Búsqueda para autocompletado en formularios desde RAM
  List<Provider> searchCachedProviders(String query) {
    return _cachedProviders.where((p) => 
      p.nombre.toLowerCase().contains(query.toLowerCase()) || 
      (p.ruc?.contains(query) ?? false)
    ).toList();
  }

  Future<void> removeProvider(String id) async {
    await _repo.deleteProvider(id);
    await refreshProviders();
  }

  void dispose() {
    _providerController.close();
  }


  // ==========================================================
  // MOTOR ALGORÍTMICO DE IA Y PRESCRIPCIÓN DE SUMINISTRO (EDGE)
  // ==========================================================



  /// Analiza el histórico transaccional de un producto y prescribe 
  /// el proveedor óptimo basándose en costo y estabilidad de precios.
  Future<Map<String, dynamic>?> getBestProviderForProduct(String productId) async {
    // 1. Extraer el dataset local desde el repositorio (JOIN de SQLite)
    final List<Map<String, dynamic>> history = 
        await _repo.getPurchaseHistoryByProduct(productId);

    if (history.isEmpty) return null; // No hay compras previas para analizar

    // Estructuras temporales en RAM para agrupar costos por proveedor
    final Map<String, List<double>> providerCosts = {};
    final Map<String, String> providerNames = {};

    for (var row in history) {
      final String id = row['provider_id'];
      final String name = row['provider_name'];
      final double cost = row['cost'];

      providerNames[id] = name;
      providerCosts.putIfAbsent(id, () => []).add(cost);
    }

    String? bestProviderId;
    double minScore = double.infinity;
    double finalEstimatedCost = 0.0;
    double finalVolatility = 0.0;

    // 2. Procesamiento algorítmico por cada proveedor identificado
    providerCosts.forEach((id, costs) {
      // Tomamos el último precio registrado (el más reciente en la cima por el ORDER BY fecha DESC)
      double latestCost = costs.first;
      
      // Calculamos la volatilidad usando la desviación estándar si hay más de una compra
      double deviation = 0.0;
      if (costs.length > 1) {
        double avg = costs.reduce((a, b) => a + b) / costs.length;
        double sumOfSquares = (costs.map((c) => pow(c - avg, 2)).reduce((a, b) => a + b).toDouble());
        deviation = sqrt(sumOfSquares / costs.length);
      }

      // MÉTRICA DE LA IA (Score): Balanceamos costo (80% peso) y riesgo de volatilidad (20% peso)
      // Un score más bajo indica una opción más económica y predecible.
      double score = (latestCost * 0.8) + (deviation * 0.2);

      if (score < minScore) {
        minScore = score;
        bestProviderId = id;
        finalEstimatedCost = latestCost;
        finalVolatility = deviation;
      }
    });

    if (bestProviderId == null) return null;

    // Retornamos el veredicto prescriptivo listo para ser pintado en la UI
    return {
      'provider_id': bestProviderId,
      'provider_name': providerNames[bestProviderId],
      'estimated_cost': finalEstimatedCost,
      'volatility': finalVolatility,
      'total_records_analyzed': providerCosts[bestProviderId]!.length,
    };
  }
}
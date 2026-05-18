import 'dart:async';
import '../models/products_model.dart';
import '../repositories/product_repository.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();

  factory ProductService() {
    return _instance;
  }

  final ProductRepository _repo = ProductRepository();
  
  // Caché en RAM para pintar inmediatamente en la UI mientras carga el stream
  List<Product>? _cachedProducts;
  List<Product>? get cachedProducts => _cachedProducts;

  // Stream para que la UI se entere de los cambios cuando importas datos
  final _productController = StreamController<List<Product>>.broadcast();
  Stream<List<Product>> get productStream => _productController.stream;

  ProductService._internal() {
    refreshProducts();
  }

  // Refrescar lista tras una importación desde el POS
  Future<void> refreshProducts() async {
    final products = await _repo.getAllProducts();
    _cachedProducts = products;
    _productController.add(products);
  }

  // Método unificado para UI y para Ingesta Automática
  Future<void> saveProduct(Product product) async {
    // Poner reglas de negocio comunes (ej. validar stock >= 0)
    await _repo.upsertProduct(product);
    await refreshProducts(); // Notificar a la UI
  }

  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
    await refreshProducts(); // Notificar a la UI
  }

  // Específico para el Middleware de POS
  Future<void> syncProductFromPos(Product product) async {
    // Añadir lógica específica de sincronización aquí, 
    // como marcar un flag 'isSynced' o registrar un log de auditoría
    await _repo.upsertProduct(product);
    await refreshProducts();
  }

  // Solo lectura de alertas (KPIs)
  Future<List<Product>> getProductsNeedingRestock() async {
    return await _repo.getLowStockProducts();
  }

  void dispose() {
    _productController.close();
  }
}
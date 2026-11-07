import 'dart:async';
import '../models/products_model.dart';
import '../repositories/product_repository.dart';
import '../utils/validaciones.dart';

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

  /// Comprueba que el SKU y el nombre no choquen con otro producto.
  /// El producto con [idPropio] (el que se edita) no cuenta contra sí mismo.
  /// Lanza [AppException] con el campo afectado.
  Future<void> validarUnicidad({
    required String sku,
    required String nombre,
    String? idPropio,
  }) async {
    final claveSku = normalizarClave(sku);
    final claveNombre = normalizarClave(nombre);
    final otros = (await _repo.getAllProducts()).where((p) => p.id != idPropio);

    for (final p in otros) {
      if (normalizarClave(p.id) == claveSku) {
        throw AppException('Ya existe un producto con el SKU "${p.id}"', campo: 'sku');
      }
      if (normalizarClave(p.nombre) == claveNombre) {
        throw AppException('Ya existe un producto llamado "${p.nombre}"', campo: 'nombre');
      }
      if (normalizarClave(p.id) == claveNombre) {
        throw AppException('El nombre coincide con el SKU del producto "${p.nombre}"', campo: 'nombre');
      }
      if (normalizarClave(p.nombre) == claveSku) {
        throw AppException('El SKU coincide con el nombre del producto "${p.nombre}"', campo: 'sku');
      }
    }
  }

  /// Reglas comunes de un producto. Lanza [AppException] con el campo afectado.
  void validarProducto(Product product) {
    if (product.id.trim().isEmpty) throw const AppException('El SKU es obligatorio', campo: 'sku');
    if (product.nombre.trim().isEmpty) {
      throw const AppException('El nombre es obligatorio', campo: 'nombre');
    }
    if (product.precio <= 0) {
      throw const AppException('El precio debe ser mayor que 0', campo: 'precio');
    }
    if (product.stock < 0) {
      throw const AppException('El stock no puede ser negativo', campo: 'stock');
    }
    if (product.umbralAlerta < 0) {
      throw const AppException('El umbral no puede ser negativo', campo: 'umbral');
    }
  }

  /// Alta ([esNuevo] true) o edición de un producto desde el formulario.
  Future<void> saveProduct(Product product, {bool esNuevo = false}) async {
    validarProducto(product);
    if (esNuevo) {
      await validarUnicidad(sku: product.id, nombre: product.nombre);
      await _repo.insertProduct(product);
    } else {
      await validarUnicidad(sku: product.id, nombre: product.nombre, idPropio: product.id);
      await _repo.updateProduct(product);
    }
    await refreshProducts(); // Notificar a la UI
  }

  /// Elimina el producto solo si no tiene movimientos asociados.
  Future<void> deleteProduct(String id) async {
    final movimientos = await _repo.countMovementsByProduct(id);
    if (movimientos > 0) {
      throw AppException(
        'No se puede eliminar el producto: tiene $movimientos '
        '${movimientos == 1 ? 'movimiento asociado' : 'movimientos asociados'}.',
      );
    }
    await _repo.deleteProduct(id);
    await refreshProducts(); // Notificar a la UI
  }

  Future<void> deleteAllProducts() async {
    if (await _repo.countAllMovements() > 0) {
      throw const AppException(
        'No se pueden eliminar los productos mientras existan comprobantes. Elimina primero los comprobantes.',
      );
    }
    await _repo.deleteAllProducts();
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

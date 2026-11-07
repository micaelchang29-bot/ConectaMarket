import 'dart:async';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:conectamarket/utils/periodos.dart';
import 'package:intl/intl.dart';

/// Línea de un comprobante para la lista de movimientos.
class LineaMovimiento {
  final String productId;
  final String productNombre;
  final double cantidad;
  const LineaMovimiento(this.productId, this.productNombre, this.cantidad);
}

/// Comprobante con sus líneas, tal como se muestra en la lista.
class MovimientoListado {
  final Receipt receipt;
  final String? providerNombre;
  final List<LineaMovimiento> lineas;
  const MovimientoListado(this.receipt, this.providerNombre, this.lineas);

  /// Indica si alguna línea corresponde al texto buscado (nombre o SKU).
  bool contieneProducto(String consulta) {
    final q = consulta.trim().toLowerCase();
    if (q.isEmpty) return true;
    return lineas.any((l) =>
        l.productNombre.toLowerCase().contains(q) || l.productId.toLowerCase().contains(q));
  }
}

/// Agrupa las filas de [ReceiptRepository.getReceiptLines] en comprobantes,
/// conservando el orden recibido (de la fecha más reciente a la más antigua).
List<MovimientoListado> agruparLineas(List<Map<String, dynamic>> filas) {
  final Map<String, MovimientoListado> porId = {};
  for (final f in filas) {
    final id = f['id'].toString();
    final mov = porId.putIfAbsent(
      id,
      () => MovimientoListado(Receipt.fromMap(f), f['provider_nombre'] as String?, []),
    );
    if (f['product_id'] != null) {
      final pid = f['product_id'].toString();
      mov.lineas.add(LineaMovimiento(
        pid,
        (f['product_nombre'] as String?) ?? pid,
        (f['cantidad'] as num?)?.toDouble() ?? 0,
      ));
    }
  }
  return porId.values.toList();
}

class ReceiptService {
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;

  final ReceiptRepository _repo = ReceiptRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  // Caché y stream compartidos por todas las pantallas
  List<MovimientoListado>? _cached;
  List<MovimientoListado>? get cachedMovements => _cached;
  final _receiptController = StreamController<List<MovimientoListado>>.broadcast();
  Stream<List<MovimientoListado>> get receiptStream => _receiptController.stream;

  ReceiptService._internal() {
    refreshReceipts();
  }

  Future<void> refreshReceipts() async {
    final movimientos = agruparLineas(await _repo.getReceiptLines());
    _cached = movimientos;
    _receiptController.add(movimientos);
  }

  // Lógica de negocio: Registro (o edición) completo de recibo + items
  Future<void> registerReceipt(Receipt receipt, List<ReceiptItem> items) async {
    // La validación de ítems, cantidades y stock vive en la transacción del repositorio
    await _repo.saveFullReceipt(receipt, items);

    // Actualizar el estado de la UI
    await refreshReceipts();
    await ProductService().refreshProducts();
  }

  // Lógica para obtener el detalle completo de un recibo para mostrarlo
  Future<List<ReceiptItem>> getReceiptDetails(String receiptId) async {
    return await _repo.getItemsByReceiptId(receiptId);
  }

  double calculateTotalFromItems(List<ReceiptItem> items) {
    return items.fold(0.0, (sum, item) => sum + (item.cantidad * item.costoUnitario));
  }

  // Borra el comprobante revirtiendo su efecto en el stock
  Future<void> deleteReceipt(String id) async {
    await _repo.deleteReceipt(id);
    await refreshReceipts();
    await ProductService().refreshProducts();
  }

  Future<void> deleteAllReceipts() async {
    await _repo.deleteAllReceipts();
    await refreshReceipts();
  }

  void dispose() {
    _receiptController.close();
  }


  /// METODO PRINCIPAL: Orquesta el cálculo del balance financiero del mes,
  /// o del trimestre calendario que contiene al mes si [trimestral] es true.
  Future<Map<String, dynamic>> getFinancialBalance({
    required int year,
    required int month,
    bool trimestral = false,
  }) async {
    // 1. Determinar el rango de fechas y la cantidad de días del período
    final rango = rangoPeriodo(year, month, trimestral: trimestral);
    final String startStr = _dateFormatter.format(rango.inicio);
    final String endStr = _dateFormatter.format(rango.fin);

    // 2. Extraer la data transaccional cruda desde SQLite mediante el repositorio
    final List<Map<String, dynamic>> rawItems =
        await _repo.getDetailedBalanceItemsInRange(startStr, endStr);

    // 3. Inicializar la matriz base del calendario en RAM con valores en 0.0
    final Map<String, Map<String, double>> calendarMatrix =
        _generateEmptyCalendarMatrix(rango.inicio, rango.dias);

    // 4. Volcar y acumular los montos reales calculados (cantidad * costoUnitario) sobre la matriz
    final Map<String, dynamic> processedData = _processAndAccumulateItems(rawItems, calendarMatrix);

    // 5. Formatear y construir los vectores primitivos finales limpios para la interfaz gráfica (UI)
    return _formatFinalOutput(calendarMatrix, processedData, conMes: trimestral);
  }

  // ==========================================================
  // METODOS PRIVADOS SUB-DIVIDIDOS (Módulos de Soporte)
  // ==========================================================

  /// Genera el mapa base del calendario (Calendar Master) para evitar días vacíos.
  Map<String, Map<String, double>> _generateEmptyCalendarMatrix(DateTime start, int totalDays) {
    final Map<String, Map<String, double>> matrix = {};
    for (int i = 0; i < totalDays; i++) {
      final DateTime day = DateTime(start.year, start.month, start.day + i);
      final String dayKey = _dateFormatter.format(day);
      matrix[dayKey] = {
        'ventas': 0.0,
        'compras': 0.0,
      };
    }
    return matrix;
  }

  /// Procesa el listado relacional e itera de forma matemática los subtotales.
  Map<String, dynamic> _processAndAccumulateItems(
    List<Map<String, dynamic>> rawItems,
    Map<String, Map<String, double>> calendarMatrix,
  ) {
    double totalVentas = 0.0;
    double totalCompras = 0.0;

    for (var row in rawItems) {
      final String fechaRow = row['fecha'];
      final int tipoMov = (row['tipomovimiento'] as num).toInt(); // 0 = Venta, 1 = Compra
      final double cantidad = (row['cantidad'] as num).toDouble();
      final double costoUnitario = (row['costoUnitario'] as num).toDouble();

      // Aplicación matemática estricta: subtotal = cantidad * costoUnitario
      final double itemSubtotal = cantidad * costoUnitario;

      if (calendarMatrix.containsKey(fechaRow)) {
        if (tipoMov == 0) {
          calendarMatrix[fechaRow]!['ventas'] = calendarMatrix[fechaRow]!['ventas']! + itemSubtotal;
          totalVentas += itemSubtotal;
        } else {
          calendarMatrix[fechaRow]!['compras'] = calendarMatrix[fechaRow]!['compras']! + itemSubtotal;
          totalCompras += itemSubtotal;
        }
      }
    }

    return {'total_ventas': totalVentas, 'total_compras': totalCompras};
  }

  /// Convierte la matriz interna estructurada en listas primitivas para los gráficos.
  Map<String, dynamic> _formatFinalOutput(
    Map<String, Map<String, double>> calendarMatrix,
    Map<String, dynamic> processedData, {
    bool conMes = false,
  }) {
    final sortedKeys = calendarMatrix.keys.toList()..sort();
    final List<double> vectorVentas = [];
    final List<double> vectorCompras = [];
    final List<String> etiquetasX = [];

    for (var key in sortedKeys) {
      vectorVentas.add(calendarMatrix[key]!['ventas']!);
      vectorCompras.add(calendarMatrix[key]!['compras']!);
      final d = DateTime.parse(key);
      etiquetasX.add(conMes ? '${d.day}/${d.month}' : d.day.toString());
    }

    final double ventas = processedData['total_ventas'];
    final double compras = processedData['total_compras'];

    return {
      'total_ventas': ventas,
      'total_compras': compras,
      'balance_neto': ventas - compras,
      'vector_ventas': vectorVentas,
      'vector_compras': vectorCompras,
      'etiquetas_x': etiquetasX,
    };
  }
}

import 'dart:async';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:intl/intl.dart';

class ReceiptService {
  // Singleton: todas las pantallas comparten la misma instancia para que el
  // stream de recibos llegue tambien a las secciones del dashboard.
  static final ReceiptService _instance = ReceiptService._internal();

  factory ReceiptService() {
    return _instance;
  }

  final ReceiptRepository _repo = ReceiptRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  // Caché en RAM para pintar de inmediato a quien se suscriba despues de que
  // el stream (broadcast, sin replay) ya haya emitido.
  List<Receipt>? _cachedReceipts;
  List<Receipt>? get cachedReceipts => _cachedReceipts;

  // Stream para notificar a la UI cuando cambien los recibos
  final _receiptController = StreamController<List<Receipt>>.broadcast();
  Stream<List<Receipt>> get receiptStream => _receiptController.stream;

  ReceiptService._internal() {
    refreshReceipts();
  }

  Future<void> refreshReceipts() async {
    final receipts = await _repo.getAllReceipts();
    _cachedReceipts = receipts;
    _receiptController.add(receipts);
  }

  // Lógica de negocio: Registro completo de recibo + items
  Future<void> registerReceipt(Receipt receipt, List<ReceiptItem> items) async {
    // Aquí puedes añadir validaciones de negocio antes de persistir
    if (items.isEmpty) {
      throw Exception("No se puede registrar un recibo sin ítems.");
    }
    
    // Invocación al repositorio para la transacción atómica
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

  // Lógica de borrado
  Future<void> deleteReceipt(String id) async {
    await _repo.deleteReceipt(id);
    await refreshReceipts();
    // It shouldn't necessarily refresh products on delete, wait...
    // The prompt only asked for "cada vez que se registre un recibo (ya sea de forma manual o mediante el servicio de importación de CSV), se actualice automáticamente el stock"
  }

  Future<void> deleteAllReceipts() async {
    await _repo.deleteAllReceipts();
    await refreshReceipts();
  }

  void dispose() {
    _receiptController.close();
  }


  /// METODO PRINCIPAL: Orquesta el cálculo del balance financiero.
  Future<Map<String, dynamic>> getFinancialBalance({required int year, required int month}) async {
    // 1. Determinar el rango de fechas y la cantidad de días del período
    final periodConfig = _calculatePeriodConfig(year, month);
    final String startStr = _dateFormatter.format(periodConfig['start']);
    final String endStr = _dateFormatter.format(periodConfig['end']);

    // 2. Extraer la data transaccional cruda desde SQLite mediante el repositorio
    final List<Map<String, dynamic>> rawItems = 
        await _repo.getDetailedBalanceItemsInRange(startStr, endStr);

    // 3. Inicializar la matriz base del calendario en RAM con valores en 0.0
    final Map<String, Map<String, double>> calendarMatrix = 
        _generateEmptyCalendarMatrix(periodConfig['start'], periodConfig['total_days']);

    // 4. Volcar y acumular los montos reales calculados (cantidad * costoUnitario) sobre la matriz
    final Map<String, dynamic> processedData = _processAndAccumulateItems(rawItems, calendarMatrix);

    // 5. Formatear y construir los vectores primitivos finales limpios para la interfaz gráfica (UI)
    return _formatFinalOutput(calendarMatrix, processedData);
  }

  // ==========================================================
  // METODOS PRIVADOS SUB-DIVIDIDOS (Módulos de Soporte)
  // ==========================================================

  /// Sub-Módulo 1: Calcula de forma estricta los límites temporales del período específico.
  Map<String, dynamic> _calculatePeriodConfig(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final totalDays = end.day;

    return {'start': start, 'end': end, 'total_days': totalDays};
  }

  /// Sub-Módulo 2: Genera el mapa base del calendario (Calendar Master) para evitar días vacíos.
  Map<String, Map<String, double>> _generateEmptyCalendarMatrix(DateTime start, int totalDays) {
    final Map<String, Map<String, double>> matrix = {};
    for (int i = 0; i < totalDays; i++) {
      final DateTime day = start.add(Duration(days: i));
      final String dayKey = _dateFormatter.format(day);
      matrix[dayKey] = {
        'ventas': 0.0,
        'compras': 0.0,
      };
    }
    return matrix;
  }

  /// Sub-Módulo 3: Procesa el listado relacional e itera de forma matemática los subtotales.
  Map<String, dynamic> _processAndAccumulateItems(
    List<Map<String, dynamic>> rawItems, 
    Map<String, Map<String, double>> calendarMatrix,
  ) {
    double totalVentas = 0.0;
    double totalCompras = 0.0;

    for (var row in rawItems) {
      final String fechaRow = row['fecha'];
      final int tipoMov = row['tipomovimiento']; // 0 = Venta, 1 = Compra
      final int cantidad = (row['cantidad'] as num).toInt();
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

  /// Sub-Módulo 4: Convierte la matriz interna estructurada en listas primitivas para los gráficos.
  Map<String, dynamic> _formatFinalOutput(
    Map<String, Map<String, double>> calendarMatrix, 
    Map<String, dynamic> processedData,
  ) {
    final sortedKeys = calendarMatrix.keys.toList()..sort();
    final List<double> vectorVentas = [];
    final List<double> vectorCompras = [];
    final List<String> etiquetasX = [];

    for (var key in sortedKeys) {
      vectorVentas.add(calendarMatrix[key]!['ventas']!);
      vectorCompras.add(calendarMatrix[key]!['compras']!);
      etiquetasX.add(DateTime.parse(key).day.toString()); // Extrae solo el número de día
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
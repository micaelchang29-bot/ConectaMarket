import 'dart:convert';
import 'dart:io';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:csv/csv.dart';
import '../../models/products_model.dart';
import '../../repositories/product_repository.dart';

class CsvImportService {
  final ProductRepository _repo = ProductRepository();
  final ReceiptRepository _receiptRepository = ReceiptRepository();

  Future<void> importProductsFromCsv(String filePath) async {
    final file = File(filePath);
    final String content = await file.readAsString(encoding: utf8);

    final List<List<dynamic>> rows = Csv(dynamicTyping: true).decode(content);

    // Iteramos saltando el encabezado (índice 0)
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      
      final product = Product(
        id: row[0].toString(),
        nombre: row[1].toString(),
        stock: (row[2] as num).toDouble(), // row[2] ya es num gracias a dynamicTyping
        umbralAlerta: (row[3] as int),
      );

      await _repo.upsertProduct(product);
    }
    await ProductService().refreshProducts();
  }

  Future<void> importReceiptsFromCsv(String filePath) async {
    final file = File(filePath);
    final String content = await file.readAsString(encoding: utf8);

    // Usamos el decoder de la versión 8+ de csv
    // dynamicTyping: true convierte automáticamente números y booleanos si es posible
    final List<List<dynamic>> fields = Csv(dynamicTyping: true).decode(content);

    // Mapas temporales para agrupar recibos y sus ítems
    Map<String, Receipt> receiptsMap = {};
    Map<String, List<ReceiptItem>> itemsMap = {};

    // Iteramos desde 1 para saltar el encabezado
    for (var i = 1; i < fields.length; i++) {
      final row = fields[i];
      final rId = row[0].toString(); // receipt_id
      
      // 1. Si no existe la cabecera en nuestro mapa, la creamos
      if (!receiptsMap.containsKey(rId)) {
        // Extraemos el valor y validamos si viene vacío o como texto nulo
        final String rawProviderId = row[1].toString().trim();
        final String? cleanedProviderId = (rawProviderId.isEmpty || rawProviderId == 'null') 
            ? null 
            : rawProviderId;

        receiptsMap[rId] = Receipt(
          id: rId,
          providerId: cleanedProviderId, // <--- Ahora pasará un null real si es una venta, evitando el fallo de FOREIGN KEY
          fecha: row[2].toString(),
          total: (row[3] as num).toDouble(),
          tipomovimiento: row[4] == 1, 
        );
        itemsMap[rId] = [];
      }

      // 2. Creamos y agregamos el ítem al mapa correspondiente
      final item = ReceiptItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
        receiptId: rId,
        productId: row[5].toString(),
        cantidad: (row[6] as num).toDouble(),
        costoUnitario: (row[7] as num).toDouble(),
      );
      
      itemsMap[rId]!.add(item);
    }

    // 3. Guardado transaccional en el Repositorio
    for (var rId in receiptsMap.keys) {
      final receipt = receiptsMap[rId]!;
      final items = itemsMap[rId]!;
      if (items.isEmpty) {
        throw Exception("No se puede registrar un recibo sin ítems.");
      }
      await _receiptRepository.saveFullReceipt(receipt, items);
    }
    
    // 4. Refrescar el catálogo de productos
    await ProductService().refreshProducts();
  }
  
}
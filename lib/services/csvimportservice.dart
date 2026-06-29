import 'dart:convert';
import 'dart:io';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:csv/csv.dart';
import '../../models/products_model.dart';
import '../../repositories/product_repository.dart';

class CsvImportResult {
  final int imported;
  final List<String> errors;

  const CsvImportResult({required this.imported, required this.errors});
}

class CsvImportService {
  final ProductRepository _repo = ProductRepository();
  final ReceiptRepository _receiptRepository = ReceiptRepository();

  Future<CsvImportResult> importProductsFromCsv(String filePath) async {
    final file = File(filePath);
    final String content = await file.readAsString(encoding: utf8);
    final List<List<dynamic>> rows = Csv(dynamicTyping: true).decode(content);

    int imported = 0;
    final List<String> errors = [];

    for (var i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        if (row.length < 4) throw Exception('Columnas insuficientes (se esperan 4)');

        final product = Product(
          id: row[0].toString(),
          nombre: row[1].toString(),
          stock: (row[2] as num).toDouble(),
          umbralAlerta: (row[3] as num).toInt(),
        );

        await _repo.upsertProduct(product);
        imported++;
      } catch (e) {
        errors.add('Fila ${i + 1}: $e');
      }
    }

    await ProductService().refreshProducts();
    return CsvImportResult(imported: imported, errors: errors);
  }

  Future<CsvImportResult> importReceiptsFromCsv(String filePath) async {
    final file = File(filePath);
    final String content = await file.readAsString(encoding: utf8);
    final List<List<dynamic>> fields = Csv(dynamicTyping: true).decode(content);

    Map<String, Receipt> receiptsMap = {};
    Map<String, List<ReceiptItem>> itemsMap = {};
    final List<String> errors = [];

    for (var i = 1; i < fields.length; i++) {
      try {
        final row = fields[i];
        if (row.length < 8) throw Exception('Columnas insuficientes (se esperan al menos 8)');

        final rId = row[0].toString();

        if (!receiptsMap.containsKey(rId)) {
          final String rawProviderId = row[1].toString().trim();
          final String? cleanedProviderId =
              (rawProviderId.isEmpty || rawProviderId == 'null') ? null : rawProviderId;

          final String rawSerie = row.length > 8 ? row[8].toString().trim() : '';
          receiptsMap[rId] = Receipt(
            id: rId,
            providerId: cleanedProviderId,
            fecha: row[2].toString(),
            total: (row[3] as num).toDouble(),
            tipomovimiento: row[4] == 1,
            serie: rawSerie.isEmpty ? 'B001' : rawSerie,
          );
          itemsMap[rId] = [];
        }

        itemsMap[rId]!.add(ReceiptItem(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          receiptId: rId,
          productId: row[5].toString(),
          cantidad: (row[6] as num).toDouble(),
          costoUnitario: (row[7] as num).toDouble(),
        ));
      } catch (e) {
        errors.add('Fila ${i + 1}: $e');
      }
    }

    int imported = 0;
    for (var rId in receiptsMap.keys) {
      try {
        final items = itemsMap[rId]!;
        if (items.isEmpty) throw Exception('Recibo sin ítems');
        await _receiptRepository.saveFullReceipt(receiptsMap[rId]!, items);
        imported++;
      } catch (e) {
        errors.add('Recibo $rId: $e');
      }
    }

    await ProductService().refreshProducts();
    return CsvImportResult(imported: imported, errors: errors);
  }
}

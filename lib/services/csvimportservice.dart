import 'dart:convert';
import 'dart:io';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/repositories/provider_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:conectamarket/services/provider_service.dart';
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
  final ProviderRepository _providerRepository = ProviderRepository();

  Future<CsvImportResult> importProvidersFromCsv(String filePath) async {
    final file = File(filePath);
    final String content = await file.readAsString(encoding: utf8);
    final List<List<dynamic>> rows = Csv(dynamicTyping: true).decode(content);

    int imported = 0;
    final List<String> errors = [];

    for (var i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        if (row.length < 2) throw Exception('Columnas insuficientes (se esperan al menos 2: id, nombre)');

        final provider = Provider(
          id: row[0].toString().trim(),
          nombre: row[1].toString().trim(),
          ruc: row.length > 2 ? row[2].toString().trim() : '',
          telefono: row.length > 3 ? row[3].toString().trim() : '',
        );

        await _providerRepository.upsertProvider(provider);
        imported++;
      } catch (e) {
        errors.add('Fila ${i + 1}: $e');
      }
    }

    return CsvImportResult(imported: imported, errors: errors);
  }

  Future<CsvImportResult> importProductsFromCsv(String filePath) async {
    final file = File(filePath);
    final String content = await file.readAsString(encoding: utf8);
    final List<List<dynamic>> rows = Csv(dynamicTyping: true).decode(content);

    int imported = 0;
    final List<String> errors = [];

    for (var i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        if (row.length < 4) {
          throw Exception('Columnas insuficientes (se esperan al menos 4: id, nombre, stock, umbralAlerta)');
        }

        // La 5a columna (precio de venta) es opcional para seguir aceptando
        // los CSV antiguos de 4 columnas: en ese caso el precio queda en 0.
        double precio = 0;
        if (row.length >= 5 && row[4].toString().trim().isNotEmpty) {
          precio = num.parse(row[4].toString().trim()).toDouble();
          if (precio <= 0) {
            throw Exception('El precio de venta debe ser mayor a 0');
          }
        }

        final product = Product(
          id: row[0].toString(),
          nombre: row[1].toString(),
          stock: num.parse(row[2].toString()).toDouble(),
          umbralAlerta: num.parse(row[3].toString()).toInt(),
          precio: precio,
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

    // Caché nombre -> id para no consultar la BD por cada fila y evitar duplicados
    // cuando el mismo proveedor aparece en varias filas del CSV.
    final Map<String, String> providerIdByName = {};
    for (final p in await _providerRepository.getAllProviders()) {
      providerIdByName[p.nombre.trim().toLowerCase()] = p.id;
    }

    for (var i = 1; i < fields.length; i++) {
      try {
        final row = fields[i];
        if (row.length < 8) throw Exception('Columnas insuficientes (se esperan al menos 8)');

        final String rawComprobante = row[0].toString();
        final String rawProviderName = row[1].toString().trim();
        String? providerId;

        if (rawProviderName.isNotEmpty && rawProviderName != 'null' && rawProviderName != '0') {
          final String key = rawProviderName.toLowerCase();
          providerId = providerIdByName[key];

          // El proveedor no existe todavía en la BD: se crea con ese nombre
          // para que el recibo quede vinculado desde ya (y aparezca en el ranking).
          if (providerId == null) {
            final newProvider = Provider(
              id: 'PROV-${DateTime.now().millisecondsSinceEpoch}-$i',
              nombre: rawProviderName,
            );
            await _providerRepository.upsertProvider(newProvider);
            providerId = newProvider.id;
            providerIdByName[key] = providerId;
          }
        }

        // El Nº de comprobante del CSV no es único globalmente (cada proveedor
        // suele numerar sus propios comprobantes desde 1): se namespacea por
        // proveedor para no fusionar compras de proveedores distintos bajo el
        // mismo recibo.
        final String rId = '${providerId ?? "SP"}_$rawComprobante';

        if (!receiptsMap.containsKey(rId)) {
          final String rawSerie = row.length > 8 ? row[8].toString().trim() : '';
          receiptsMap[rId] = Receipt(
            id: 'REC-${DateTime.now().microsecondsSinceEpoch}-$i',
            providerId: providerId,
            fecha: row[2].toString(),
            total: num.parse(row[3].toString()).toDouble(),
            tipomovimiento: row[4].toString().trim() == '1',
            serie: rawSerie.isEmpty ? 'B001' : rawSerie,
          );
          itemsMap[rId] = [];
        }

        itemsMap[rId]!.add(ReceiptItem(
          id: '${DateTime.now().microsecondsSinceEpoch}-$i',
          receiptId: receiptsMap[rId]!.id,
          productId: row[5].toString(),
          cantidad: num.parse(row[6].toString()).toDouble(),
          costoUnitario: num.parse(row[7].toString()).toDouble(),
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
    await ProviderService().refreshProviders();
    return CsvImportResult(imported: imported, errors: errors);
  }
}

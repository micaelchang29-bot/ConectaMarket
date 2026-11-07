import 'dart:convert';
import 'dart:io';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/repositories/provider_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:conectamarket/services/provider_service.dart';
import 'package:conectamarket/services/receipt_service.dart';
import 'package:conectamarket/utils/validaciones.dart';
import 'package:csv/csv.dart';
import '../../models/products_model.dart';
import '../../repositories/product_repository.dart';

class CsvImportResult {
  /// Filas del archivo cargadas correctamente.
  final int imported;
  /// Comprobantes creados (solo en la importación de comprobantes).
  final int? comprobantes;
  final List<String> errors;

  const CsvImportResult({required this.imported, required this.errors, this.comprobantes});
}

/// Lee un número de una celda aceptando coma decimal. Lanza un error legible.
double numeroDeCelda(dynamic valor, String columna) {
  if (valor is num) return valor.toDouble();
  final n = parseDecimal(valor?.toString());
  if (n == null) {
    final texto = valor?.toString() ?? '';
    throw AppException(texto.trim().isEmpty
        ? 'la columna "$columna" está vacía'
        : 'la columna "$columna" no es un número ("$texto")');
  }
  return n;
}

bool _celdaVacia(List<dynamic> row, int i) =>
    row.length <= i || row[i] == null || row[i].toString().trim().isEmpty;

class CsvImportService {
  final ProductRepository _repo = ProductRepository();
  final ReceiptRepository _receiptRepository = ReceiptRepository();
  final ProviderRepository _providerRepository = ProviderRepository();

  Future<CsvImportResult> importProductsFromCsv(String filePath) async {
    final file = File(filePath);
    final String content = await file.readAsString(encoding: utf8);
    final List<List<dynamic>> rows = Csv(dynamicTyping: true).decode(content);

    int imported = 0;
    final List<String> errors = [];

    // Productos existentes para conservar el precio y evitar nombres repetidos
    final Map<String, Product> existentes = {
      for (final p in await _repo.getAllProducts()) p.id: p,
    };

    for (var i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        if (row.length < 4) {
          throw const AppException('columnas insuficientes (se esperan sku, nombre, stock y umbral)');
        }

        final String sku = row[0].toString().trim();
        final String nombre = row[1].toString().trim();
        if (sku.isEmpty) throw const AppException('el SKU está vacío');
        if (nombre.isEmpty) throw const AppException('el nombre está vacío');

        final double stock = numeroDeCelda(row[2], 'stock');
        if (stock < 0) throw const AppException('el stock no puede ser negativo');
        final double umbral = numeroDeCelda(row[3], 'umbral');
        if (umbral < 0 || umbral != umbral.roundToDouble()) {
          throw const AppException('el umbral debe ser un entero mayor o igual a 0');
        }

        // Precio (columna 5) opcional: si no viene se conserva el registrado
        double precio = existentes[sku]?.precio ?? 0;
        if (!_celdaVacia(row, 4)) {
          precio = numeroDeCelda(row[4], 'precio');
          if (precio <= 0) throw const AppException('el precio debe ser mayor que 0');
        }

        final clave = normalizarClave(nombre);
        final choque = existentes.values.where((p) => p.id != sku && normalizarClave(p.nombre) == clave);
        if (choque.isNotEmpty) {
          throw AppException('ya existe otro producto llamado "${choque.first.nombre}" (SKU ${choque.first.id})');
        }

        final product = Product(
          id: sku,
          nombre: nombre,
          stock: stock,
          umbralAlerta: umbral.toInt(),
          precio: precio,
        );

        await _repo.upsertProduct(product);
        existentes[sku] = product;
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
        if (row.length < 7) {
          throw const AppException('columnas insuficientes (se esperan al menos 7)');
        }

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
            total: numeroDeCelda(row[3], 'total'),
            tipomovimiento: row[4].toString().trim() == '1',
            serie: rawSerie.isEmpty ? 'B001' : rawSerie,
          );
          itemsMap[rId] = [];
        }

        final String productId = row[5].toString().trim();
        final double cantidad = numeroDeCelda(row[6], 'cantidad');
        if (cantidad <= 0) throw const AppException('la cantidad debe ser mayor que 0');

        // Sin precio unitario en el archivo se usa el precio registrado del producto
        double costo;
        if (_celdaVacia(row, 7)) {
          final producto = await _repo.getProductById(productId);
          if (producto == null) throw AppException('el producto $productId no existe');
          if (producto.precio <= 0) {
            throw AppException('falta el precio unitario y el producto $productId no tiene precio registrado');
          }
          costo = producto.precio;
        } else {
          costo = numeroDeCelda(row[7], 'precio');
          if (costo <= 0) throw const AppException('el precio unitario debe ser mayor que 0');
        }

        itemsMap[rId]!.add(ReceiptItem(
          id: '${DateTime.now().microsecondsSinceEpoch}-$i',
          receiptId: receiptsMap[rId]!.id,
          productId: productId,
          cantidad: cantidad,
          costoUnitario: costo,
        ));
      } catch (e) {
        errors.add('Fila ${i + 1}: $e');
      }
    }

    int imported = 0;
    int comprobantes = 0;
    for (var rId in receiptsMap.keys) {
      try {
        final items = itemsMap[rId]!;
        if (items.isEmpty) throw const AppException('ninguna fila válida');
        await _receiptRepository.saveFullReceipt(receiptsMap[rId]!, items);
        comprobantes++;
        imported += items.length;
      } catch (e) {
        errors.add('Recibo $rId: $e');
      }
    }

    await ProductService().refreshProducts();
    await ProviderService().refreshProviders();
    await ReceiptService().refreshReceipts();
    return CsvImportResult(imported: imported, errors: errors, comprobantes: comprobantes);
  }
}

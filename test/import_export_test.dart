import 'dart:io';

import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/services/csvimportservice.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:conectamarket/services/provider_export_service.dart';
import 'package:conectamarket/services/receipt_service.dart';
import 'package:conectamarket/services/sunat_service.dart';
import 'package:conectamarket/utils/validaciones.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

void main() {
  late Directory dir;

  setUp(() async {
    await abrirBaseDePrueba();
    dir = await Directory.systemTemp.createTemp('cm_csv');
  });
  tearDown(() async {
    await cerrarBaseDePrueba();
    await dir.delete(recursive: true);
  });

  Future<String> archivo(String nombre, String contenido) async {
    final f = File(p.join(dir.path, nombre));
    await f.writeAsString(contenido);
    return f.path;
  }

  group('Importación CSV (CP-06)', () {
    test('productos sin columna precio y 3 filas con texto: carga las válidas y reporta las malas', () async {
      final ruta = await archivo('productos.csv', [
        'sku,nombre,stock,umbral',
        'P001,Arroz,10,5',
        'P002,Azúcar,abc,5',
        'P003,Aceite,8,2',
        'P004,Fideos,diez,2',
        'P005,Sal,xx,1',
        'P006,Leche,3,1',
      ].join('\n'));

      final r = await CsvImportService().importProductsFromCsv(ruta);
      expect(r.imported, 3);
      expect(r.errors.length, 3);
      expect(r.errors.first, 'Fila 3: la columna "stock" no es un número ("abc")');
      expect(ProductService().cachedProducts!.map((x) => x.id), containsAll(['P001', 'P003', 'P006']));
    });

    test('el resumen cuenta filas, no comprobantes (CP-06-01)', () async {
      await crearProducto('P001', 'Arroz', stock: 100, precio: 4.5);
      await crearProducto('P002', 'Azúcar', stock: 100, precio: 3);
      final ruta = await archivo('ventas_caja.csv', [
        'comprobante,proveedor,fecha,total,tipo,producto_id,cantidad,costo',
        '1,,2026-11-01,15,0,P001,2,4.5',
        '1,,2026-11-01,15,0,P002,2,3',
        '2,,2026-11-02,9,0,P001,2,4.5',
      ].join('\n'));
      final r = await CsvImportService().importReceiptsFromCsv(ruta);
      expect(r.errors, isEmpty);
      expect(r.imported, 3);
      expect(r.comprobantes, 2);
    });

    test('productos: precio opcional, coma decimal y nombre repetido con otro SKU', () async {
      await crearProducto('P001', 'Arroz', precio: 4.5);
      final ruta = await archivo('productos.csv', [
        'sku;nombre;stock;umbral;precio',
        'P001;Arroz;20;5;',
        'P002;Azúcar;5;1;"3,20"',
        'P003;ARROZ;5;1;2',
        'P004;Sal;-2;1;1',
      ].join('\n'));

      final r = await CsvImportService().importProductsFromCsv(ruta);
      expect(r.imported, 2);
      expect(r.errors, hasLength(2));
      final porId = {for (final x in ProductService().cachedProducts!) x.id: x};
      expect(porId['P001']!.precio, 4.5, reason: 'sin precio se conserva el registrado');
      expect(porId['P001']!.stock, 20);
      expect(porId['P002']!.precio, 3.2);
    });

    test('comprobantes: filas con texto en cantidad se reportan; las válidas se cargan y la lista se refresca', () async {
      await crearProducto('P001', 'Arroz', stock: 100, precio: 4.5);
      final ruta = await archivo('ventas_caja.csv', [
        'comprobante,proveedor,fecha,total,tipo,producto_id,cantidad,costo',
        '1,,2026-11-01,9,0,P001,2,4.5',
        '2,,2026-11-02,9,0,P001,tres,4.5',
        '3,,2026-11-03,9,0,P001,2,',
      ].join('\n'));

      final r = await CsvImportService().importReceiptsFromCsv(ruta);
      expect(r.errors.where((e) => e.startsWith('Fila 3')), hasLength(1));
      expect(r.imported, 2, reason: 'la fila sin costo usa el precio del producto');
      expect(await stockDe('P001'), 96);
      expect(ReceiptService().cachedMovements!.length, 2);
    });
  });

  group('Exportar proveedores (0002194)', () {
    test('Excel con nombre, RUC y teléfono ordenado por nombre', () {
      final bytes = ProviderExportService().construirExcel([
        Provider(id: '2', nombre: 'Zeta SAC', ruc: '20111111111', telefono: '987654321'),
        Provider(id: '1', nombre: 'Alfa EIRL', ruc: '10222222222', telefono: '014567890'),
      ]);
      final excel = Excel.decodeBytes(bytes);
      final hoja = excel.tables['Proveedores']!;
      String celda(int fila, int col) => hoja.rows[fila][col]!.value.toString();
      expect([celda(0, 0), celda(0, 1), celda(0, 2)], ['Nombre', 'RUC', 'Teléfono']);
      expect([celda(1, 0), celda(1, 1), celda(1, 2)], ['Alfa EIRL', '10222222222', '014567890']);
      expect(celda(2, 0), 'Zeta SAC');
      expect(hoja.maxRows, 3);
    });

    test('sin proveedores avisa', () {
      expect(() => ProviderExportService().construirExcel([]), throwsA(isA<AppException>()));
    });

    test('nombre del archivo', () {
      expect(ProviderExportService.nombreArchivo(DateTime(2026, 11, 6)), 'Proveedores_20261106.xlsx');
    });
  });

  test('SUNAT: un periodo sin ventas no genera archivo (CP-19-02)', () async {
    expect(() => SunatService().exportToExcel(2026, 1),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('No hay ventas'))));
  });
}

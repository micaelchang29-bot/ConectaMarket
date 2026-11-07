import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/providers_model.dart';
import '../utils/validaciones.dart';

/// Genera el Excel de proveedores (nombre, RUC y teléfono).
class ProviderExportService {
  static const encabezados = ['Nombre', 'RUC', 'Teléfono'];

  /// Nombre del archivo: Proveedores_AAAAMMDD.xlsx
  static String nombreArchivo(DateTime fecha) =>
      'Proveedores_${DateFormat('yyyyMMdd').format(fecha)}.xlsx';

  /// Bytes del libro con una fila por proveedor, ordenados por nombre.
  List<int> construirExcel(List<Provider> proveedores) {
    if (proveedores.isEmpty) throw const AppException('No hay proveedores para exportar.');

    final excel = Excel.createExcel();
    const hoja = 'Proveedores';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', hoja);
    final sheet = excel[hoja];

    sheet.appendRow(encabezados.map((h) => TextCellValue(h)).toList());
    final estilo = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#005440'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    for (int col = 0; col < encabezados.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = estilo;
    }

    final ordenados = [...proveedores]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    for (final p in ordenados) {
      // RUC y teléfono como texto para no perder ceros ni formato
      sheet.appendRow([
        TextCellValue(p.nombre),
        TextCellValue(p.ruc ?? ''),
        TextCellValue(p.telefono ?? ''),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) throw const AppException('No se pudo generar el archivo Excel.');
    return bytes;
  }

  /// Escribe el archivo en la carpeta de documentos de la app y devuelve su ruta.
  Future<String> exportar(List<Provider> proveedores, {DateTime? fecha}) async {
    final bytes = construirExcel(proveedores);
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${nombreArchivo(fecha ?? DateTime.now())}';
    await File(path).writeAsBytes(bytes);
    return path;
  }
}

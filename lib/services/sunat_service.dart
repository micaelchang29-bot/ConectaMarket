import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SunatService {
  final ReceiptRepository _repo = ReceiptRepository();

  Future<List<Map<String, dynamic>>> buildRegistroVentasRows(int year, int month) async {
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final endDate = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final sales = await _repo.getSalesForPeriod(startDate, endDate);

    return List.generate(sales.length, (i) {
      final s = sales[i];
      final total = (s['total'] as num).toDouble();
      final baseImponible = total / 1.18;
      final igv = total * 0.18 / 1.18;

      String fechaFormateada;
      try {
        final dt = DateTime.parse(s['fecha'] as String);
        fechaFormateada = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        fechaFormateada = s['fecha'] as String;
      }

      return {
        'correlativo': i + 1,
        'fecha_emision': fechaFormateada,
        'fecha_vencimiento': fechaFormateada,
        'tipo_comprobante': '03',
        'serie': s['serie'] ?? 'B001',
        'numero': s['id'],
        'tipo_doc_cliente': '-',
        'num_doc_cliente': '-',
        'razon_social_cliente': '-',
        'valor_exportacion': 0.00,
        'base_imponible': double.parse(baseImponible.toStringAsFixed(2)),
        'operaciones_exoneradas': 0.00,
        'isc': 0.00,
        'igv': double.parse(igv.toStringAsFixed(2)),
        'otros_tributos': 0.00,
        'importe_total': double.parse(total.toStringAsFixed(2)),
        'tipo_cambio': 1.000,
      };
    });
  }

  Future<String> exportToExcel(int year, int month) async {
    final rows = await buildRegistroVentasRows(year, month);

    final excel = Excel.createExcel();
    final sheet = excel['Registro de Ventas'];
    excel.setDefaultSheet('Registro de Ventas');

    const headers = [
      'Correlativo', 'Fecha Emisión', 'Fecha Vcto.', 'Tipo Comp.',
      'Serie', 'Número', 'Tipo Doc. Cliente', 'N° Doc. Cliente',
      'Razón Social Cliente', 'Valor Exportación', 'Base Imponible',
      'Op. Exoneradas', 'ISC', 'IGV', 'Otros Tributos', 'Importe Total',
      'Tipo Cambio',
    ];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#005440'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    final headerRow = headers.map((h) {
      final cell = TextCellValue(h);
      return cell;
    }).toList();

    sheet.appendRow(headerRow);

    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final row in rows) {
      sheet.appendRow([
        IntCellValue(row['correlativo'] as int),
        TextCellValue(row['fecha_emision'] as String),
        TextCellValue(row['fecha_vencimiento'] as String),
        TextCellValue(row['tipo_comprobante'] as String),
        TextCellValue(row['serie'] as String),
        TextCellValue(row['numero'] as String),
        TextCellValue(row['tipo_doc_cliente'] as String),
        TextCellValue(row['num_doc_cliente'] as String),
        TextCellValue(row['razon_social_cliente'] as String),
        DoubleCellValue(row['valor_exportacion'] as double),
        DoubleCellValue(row['base_imponible'] as double),
        DoubleCellValue(row['operaciones_exoneradas'] as double),
        DoubleCellValue(row['isc'] as double),
        DoubleCellValue(row['igv'] as double),
        DoubleCellValue(row['otros_tributos'] as double),
        DoubleCellValue(row['importe_total'] as double),
        DoubleCellValue(row['tipo_cambio'] as double),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final monthStr = month.toString().padLeft(2, '0');
    final filePath = '${dir.path}/RegistroVentas_${year}_$monthStr.xlsx';

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('No se pudo generar el archivo Excel.');

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    return filePath;
  }
}

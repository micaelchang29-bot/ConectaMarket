import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../services/sunat_service.dart';
import '../widgets_global/month_selector_widget.dart';

class SunatExportScreen extends StatefulWidget {
  const SunatExportScreen({super.key});

  @override
  State<SunatExportScreen> createState() => _SunatExportScreenState();
}

class _SunatExportScreenState extends State<SunatExportScreen> {
  final SunatService _service = SunatService();

  final now = DateTime.now();
  late int _year;
  late int _month;

  Future<List<Map<String, dynamic>>>? _previewFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _month = DateTime.now().month;
    _loadPreview();
  }

  void _loadPreview() {
    setState(() {
      _previewFuture = _service.buildRegistroVentasRows(_year, _month);
    });
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final path = await _service.exportToExcel(_year, _month);
      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: const Color(0xFFBA1A1A)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF005440),
        foregroundColor: Colors.white,
        title: const Text('Exportar Registro de Ventas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MonthSelectorWidget(
                initialYear: _year,
                initialMonth: _month,
                onMonthChanged: (y, m) {
                  _year = y;
                  _month = m;
                  _loadPreview();
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Vista previa',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _previewFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0F6E56)));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFBA1A1A))));
                  }

                  final rows = snapshot.data ?? [];

                  if (rows.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFBEC9C3)),
                          SizedBox(height: 12),
                          Text('Sin ventas en este período', style: TextStyle(color: Color(0xFF3F4944))),
                        ],
                      ),
                    );
                  }

                  final previewRows = rows.take(10).toList();
                  final remaining = rows.length - previewRows.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF005440)),
                              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                              dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF191C1D)),
                              columnSpacing: 16,
                              columns: const [
                                DataColumn(label: Text('N°')),
                                DataColumn(label: Text('Fecha')),
                                DataColumn(label: Text('Serie-Número')),
                                DataColumn(label: Text('Base Imp.')),
                                DataColumn(label: Text('IGV')),
                                DataColumn(label: Text('Total')),
                              ],
                              rows: previewRows.map((row) {
                                return DataRow(cells: [
                                  DataCell(Text('${row['correlativo']}')),
                                  DataCell(Text(row['fecha_emision'] as String)),
                                  DataCell(Text('${row['serie']}-${row['numero']}')),
                                  DataCell(Text('S/ ${(row['base_imponible'] as double).toStringAsFixed(2)}')),
                                  DataCell(Text('S/ ${(row['igv'] as double).toStringAsFixed(2)}')),
                                  DataCell(Text('S/ ${(row['importe_total'] as double).toStringAsFixed(2)}')),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      if (remaining > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Text(
                            'y $remaining más...',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF3F4944), fontStyle: FontStyle.italic),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Text(
                          'Total: ${rows.length} ventas',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F6E56)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _isExporting ? null : _export,
                icon: _isExporting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_outlined),
                label: Text(_isExporting ? 'Exportando...' : 'Exportar Excel'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F6E56),
                  disabledBackgroundColor: const Color(0xFF0F6E56).withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

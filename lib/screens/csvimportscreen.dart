import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../services/csvimportservice.dart';
import '../services/product_service.dart';
import '../services/receipt_service.dart';
import '../services/provider_service.dart';
import '../widgets_global/header_bar.dart';

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  int _selectedIndex = 0; // 0: Productos, 1: Comprobantes, 2: Proveedores
  String? _fileName;
  String? _filePath;
  bool _isLoading = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
        _filePath = result.files.single.path;
      });
    }
  }

  Future<void> _importData() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);

    try {
      final service = CsvImportService();
      final result = _selectedIndex == 0
          ? await service.importProductsFromCsv(_filePath!)
          : _selectedIndex == 1
              ? await service.importReceiptsFromCsv(_filePath!)
              : await service.importProvidersFromCsv(_filePath!);

      if (mounted) {
        setState(() {
          _fileName = null;
          _filePath = null;
        });
        _showImportSummary(result.imported, result.errors);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImportSummary(int imported, List<String> errors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resumen de importación'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF005440)),
                  const SizedBox(width: 8),
                  Text('$imported fila(s) importadas correctamente'),
                ],
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.warning, color: Color(0xFFBA1A1A)),
                    const SizedBox(width: 8),
                    Text('${errors.length} fila(s) con error:'),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        errors[i],
                        style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

    Future<void> _clearDatabase() async {
    final entityName = _selectedIndex == 0 ? "productos" : _selectedIndex == 1 ? "comprobantes" : "proveedores";
    final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar'),
      content: Text('¿Seguro que deseas eliminar todos los $entityName?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
    );

    if (confirm != true) return;

    setState(() {
    _isLoading = true;
    });

    try {
    if (_selectedIndex == 0) {
      await ProductService().deleteAllProducts();
    } else if (_selectedIndex == 1) {
      await ReceiptService().deleteAllReceipts();
    } else {
      await ProviderService().deleteAllProviders();
    }

    if (mounted) {
      final entityName = _selectedIndex == 0 ? "Productos" : _selectedIndex == 1 ? "Comprobantes" : "Proveedores";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$entityName eliminados correctamente')),
      );
    }
    } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
    } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    }
    }

    @override  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBarWidget(
        title: "Importar Datos",
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Toggle Switch
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildTabButton("Productos", 0)),
                    Expanded(child: _buildTabButton("Comprobantes", 1)),
                    Expanded(child: _buildTabButton("Proveedores", 2)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Zona de Carga
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors
                        .grey
                        .shade100, // Un color de fondo suave para diferenciar la caja
                    borderRadius: BorderRadius.circular(12),
                    // Sin border.all, es una caja limpia
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload,
                        size: 48,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fileName ?? "Toca para seleccionar un archivo CSV",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // Aquí iría tu lista de historial (similar al catálogo)
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: (_fileName == null || _isLoading) ? null : _importData,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF005440),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : const Text("Confirmar Importación", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading ? null : _clearDatabase,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Limpiar Base de Datos", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
              _fileName = null;
              _filePath = null;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
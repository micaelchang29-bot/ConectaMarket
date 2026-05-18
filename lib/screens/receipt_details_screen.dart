import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/receipts_model.dart';
import '../../models/receipt_items_model.dart';
import '../../services/receipt_service.dart';
import '../../services/product_service.dart';
import '../../services/provider_service.dart';
import 'product_details_addproduct_screen.dart';
import '../../widgets_global/header_bar.dart';

class ReceiptDetailsScreen extends StatefulWidget {
  final Receipt? receipt; // null = CREACIÓN, objeto = EDICIÓN

  const ReceiptDetailsScreen({super.key, this.receipt});

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _receiptService = ReceiptService();

  // Estado puramente visual de la pantalla
  late DateTime _fechaOperacion;
  late bool _isCompra;
  late TextEditingController _providerController;
  List<ReceiptItem> _items = [];
  bool _isLoadingDetails = false;
  late String _currentReceiptId;

  @override
  void initState() {
    super.initState();
    final hasReceipt = widget.receipt != null;
    _currentReceiptId = widget.receipt?.id ?? 'REC-${DateTime.now().millisecondsSinceEpoch}';
    _isCompra = hasReceipt ? widget.receipt!.tipomovimiento : false;
    _fechaOperacion = hasReceipt ? DateTime.parse(widget.receipt!.fecha) : DateTime.now();
    _providerController = TextEditingController(text: hasReceipt ? widget.receipt!.providerId : '');

    if (hasReceipt) {
      _fetchInitialDetails();
    }
  }

  @override
  void dispose() {
    _providerController.dispose();
    super.dispose();
  }

  // Carga inicial delegada al servicio
  Future<void> _fetchInitialDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final details = await _receiptService.getReceiptDetails(widget.receipt!.id);
      setState(() => _items = details);
    } catch (e) {
      _showNotification("Error al cargar ítems: $e", isError: true);
    } finally {
      setState(() => _isLoadingDetails = false);
    }
  }

  // Evento Guardar: Construye la data de la UI y la manda al servicio
  Future<void> _handleSave() async {
    if (_items.isEmpty) {
      _showNotification("Debes añadir al menos un producto", isError: true);
      return;
    }
    if (_isCompra && _providerController.text.trim().isEmpty) {
      _showNotification("El proveedor es obligatorio para compras", isError: true);
      return;
    }

    try {
      final id = _currentReceiptId;
      
      // El cálculo del total se delega a la lógica de negocio del servicio
      final total = _receiptService.calculateTotalFromItems(_items);

      final receipt = Receipt(
        id: id,
        tipomovimiento: _isCompra,
        fecha: _fechaOperacion.toIso8601String(),
        total: total,
        providerId: _isCompra ? _providerController.text.trim() : '',
      );

      await _receiptService.registerReceipt(receipt, _items);
      await ProductService().refreshProducts();

      if (mounted) {
        _showNotification("Movimiento procesado con éxito");
        Navigator.pop(context);
      }
    } catch (e) {
      _showNotification("Error al procesar: $e", isError: true);
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : Colors.teal[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.receipt != null;
    final totalText = _receiptService.calculateTotalFromItems(_items).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: HeaderBarWidget(
        title: isEditing ? "Detalle Movimiento" : "Registrar Movimiento",
        onBack: () => Navigator.pop(context),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await _receiptService.deleteReceipt(widget.receipt!.id);
                await ProductService().refreshProducts();
                if (mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoadingDetails
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text("FECHA DE MOVIMIENTO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              // Invoca el DatePicker nativo directamente en la UI
                              final date = await showDatePicker(context: context, initialDate: _fechaOperacion, firstDate: DateTime(2020), lastDate: DateTime(2101));
                              if (date != null) setState(() => _fechaOperacion = date);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFBEC9C3)), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [Text(DateFormat('yyyy-MM-dd').format(_fechaOperacion)), const Icon(Icons.calendar_today, size: 20)],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: const Color(0xFFE1E3E4), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _isCompra = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: !_isCompra ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                                      child: Text("VENTA", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: !_isCompra ? const Color(0xFF0F6E56) : Colors.black54)),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _isCompra = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: _isCompra ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                                      child: Text("COMPRA", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _isCompra ? const Color(0xFF0F6E56) : Colors.black54)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Opacity(
                            opacity: _isCompra ? 1.0 : 0.5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("PROVEEDOR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: (_providerController.text.isNotEmpty && ProviderService().cachedProviders.any((p) => p.id == _providerController.text)) 
                                      ? _providerController.text 
                                      : null,
                                  items: ProviderService().cachedProviders.map((provider) {
                                    return DropdownMenuItem<String>(
                                      value: provider.id,
                                      child: Text(
                                        provider.nombre,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _isCompra ? (String? newValue) {
                                    setState(() {
                                      _providerController.text = newValue ?? '';
                                    });
                                  } : null,
                                  decoration: InputDecoration(
                                    filled: true, 
                                    fillColor: _isCompra ? Colors.white : const Color(0xFFF3F4F5), 
                                    hintText: "Seleccione un proveedor",
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Productos", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () async {
                                  final receiptId = _currentReceiptId;
                                  final newItem = await ProductSelectorModal.show(context, receiptId);
                                  
                                  if (newItem != null) {
                                    setState(() {
                                      _items.add(newItem);
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add, color: Colors.white),
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFF0F6E56)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _items.isEmpty
                              ? const Center(child: Text("No hay productos en este movimiento"))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _items.length,
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return Card(
                                      color: Colors.white,
                                      child: ListTile(
                                        title: Text("Producto: ${item.productId}"),
                                        subtitle: Text("Cant: ${item.cantidad}  •  S/. ${item.costoUnitario}"),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => setState(() => _items.removeAt(index)),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFBEC9C3)))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("TOTAL", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text("S/. $totalText", style: const TextStyle(fontSize: 20, color: Color(0xFF0F6E56), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF005440),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Confirmar Registro", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/products_model.dart';
import '../../services/product_service.dart';
import '../../widgets_global/header_bar.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product? product; // Si es null, es modo CREACIÓN

  const ProductDetailsScreen({super.key, this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductService();

  // Controladores
  late TextEditingController _skuController;
  late TextEditingController _nombreController;
  late TextEditingController _precioController;
  late TextEditingController _stockController;
  late TextEditingController _umbralController;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores con datos existentes o vacíos
    _skuController = TextEditingController(text: widget.product?.id ?? '');
    _nombreController = TextEditingController(text: widget.product?.nombre ?? '');
    _precioController = TextEditingController(
      text: widget.product != null ? widget.product!.precio.toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(text: widget.product?.stock.toString() ?? '0');
    _umbralController = TextEditingController(text: widget.product?.umbralAlerta.toString() ?? '5');
  }
  
  @override
  void dispose() {
    _skuController.dispose();
    _nombreController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    _umbralController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final newProduct = Product(
      id: _skuController.text,
      nombre: _nombreController.text,
      precio: double.tryParse(_precioController.text.replaceAll(',', '.')) ?? 0,
      stock: double.tryParse(_stockController.text) ?? 0,
      umbralAlerta: int.tryParse(_umbralController.text) ?? 5,
    );

    await _service.saveProduct(newProduct);
    if (mounted) context.pop();
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${widget.product!.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.deleteProduct(widget.product!.id);
      if (mounted) context.pop();
    } catch (e) {
      // El producto tiene movimientos asociados: se informa el motivo y se
      // permanece en la pantalla en lugar de cerrarla.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFBA1A1A),
        ),
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFBEC9C3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF005440), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF3F4944)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: HeaderBarWidget(
        title: isEditing ? "Editar Producto" : "Nuevo Producto",
        onBack: () => context.pop(),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteProduct,
            )
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _skuController,
                decoration: _inputDecoration("SKU o Código (ID)"),
                enabled: !isEditing, // Normalmente el ID no se edita después de creado
                validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                decoration: _inputDecoration("Nombre del Producto"),
                validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _precioController,
                decoration: _inputDecoration("Precio de venta (S/)"),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Campo obligatorio";
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return "Ingrese un precio mayor a 0";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: _inputDecoration("Stock Actual"),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v!.isEmpty) return "Campo obligatorio";
                  final n = double.tryParse(v);
                  if (n == null) return "Debe ser un número válido";
                  if (n < 0) return "El stock no puede ser negativo";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _umbralController,
                decoration: _inputDecoration("Umbral de Alerta"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.isEmpty) return "Campo obligatorio";
                  if (int.tryParse(v) == null) return "Debe ser un número entero válido";
                  return null;
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFEDEEEF),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF6F7A74)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.pop(),
                  child: const Text("Cancelar", style: TextStyle(color: Color(0xFF005440), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005440),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.save, size: 20),
                  label: Text(isEditing ? "Actualizar" : "Guardar", style: const TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _saveProduct,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

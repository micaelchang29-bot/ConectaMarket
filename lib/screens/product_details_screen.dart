import 'package:flutter/material.dart';
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
  late TextEditingController _stockController;
  late TextEditingController _umbralController;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores con datos existentes o vacíos
    _skuController = TextEditingController(text: widget.product?.id ?? '');
    _nombreController = TextEditingController(text: widget.product?.nombre ?? '');
    _stockController = TextEditingController(text: widget.product?.stock.toString() ?? '0');
    _umbralController = TextEditingController(text: widget.product?.umbralAlerta.toString() ?? '5');
  }
  
  @override
  void dispose() {
    _skuController.dispose();
    _nombreController.dispose();
    _stockController.dispose();
    _umbralController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final newProduct = Product(
      id: _skuController.text,
      nombre: _nombreController.text,
      stock: double.tryParse(_stockController.text) ?? 0,
      umbralAlerta: int.tryParse(_umbralController.text) ?? 5,
    );

    await _service.saveProduct(newProduct);
    if (mounted) Navigator.pop(context);
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
        onBack: () => Navigator.pop(context),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await _service.deleteProduct(widget.product!.id);
                if (mounted) Navigator.pop(context);
              },
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
                controller: _stockController,
                decoration: _inputDecoration("Stock Actual"),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v!.isEmpty) return "Campo obligatorio";
                  if (double.tryParse(v) == null) return "Debe ser un número válido";
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
                  onPressed: () => Navigator.pop(context),
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

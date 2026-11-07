import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/products_model.dart';
import '../../services/product_service.dart';
import '../../widgets_global/header_bar.dart';
import '../../utils/validaciones.dart';

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
  late TextEditingController _precioController;

  // Errores que vienen del servicio (duplicados), mostrados dentro del campo
  final Map<String, String?> _erroresServicio = {};
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores con datos existentes o vacíos
    _skuController = TextEditingController(text: widget.product?.id ?? '');
    _nombreController = TextEditingController(text: widget.product?.nombre ?? '');
    _stockController = TextEditingController(
        text: widget.product != null ? formatoCantidad(widget.product!.stock) : '0');
    _umbralController = TextEditingController(text: widget.product?.umbralAlerta.toString() ?? '5');
    _precioController = TextEditingController(
        text: widget.product != null && widget.product!.precio > 0
            ? widget.product!.precio.toStringAsFixed(2)
            : '');
  }
  
  @override
  void dispose() {
    _skuController.dispose();
    _nombreController.dispose();
    _stockController.dispose();
    _umbralController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    setState(() => _erroresServicio.clear());
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.product != null;
    final newProduct = Product(
      id: _skuController.text.trim(),
      nombre: _nombreController.text.trim(),
      stock: parseDecimal(_stockController.text) ?? 0,
      umbralAlerta: int.tryParse(_umbralController.text.trim()) ?? 5,
      precio: parseDecimal(_precioController.text) ?? 0,
    );

    setState(() => _guardando = true);
    try {
      await _service.saveProduct(newProduct, esNuevo: !isEditing);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Producto actualizado' : 'Producto registrado con éxito'),
          backgroundColor: const Color(0xFF005440),
        ),
      );
      context.pop();
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.campo != null) {
        setState(() => _erroresServicio[e.campo!] = e.message);
      } else {
        _mostrarError(e.message);
      }
    } catch (_) {
      if (mounted) _mostrarError('No se pudo guardar el producto. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: const Color(0xFFBA1A1A)),
    );
  }

  Future<void> _eliminar() async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto eliminado'), backgroundColor: Color(0xFF005440)),
      );
      context.pop();
    } on AppException catch (e) {
      if (mounted) _mostrarError(e.message);
    }
  }

  InputDecoration _inputDecoration(String label, {String? campo}) {
    return InputDecoration(
      labelText: label,
      errorText: campo == null ? null : _erroresServicio[campo],
      errorMaxLines: 2,
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
              tooltip: 'Eliminar producto',
              onPressed: _eliminar,
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
                decoration: _inputDecoration("SKU o Código (ID)", campo: 'sku'),
                enabled: !isEditing, // Normalmente el ID no se edita después de creado
                validator: (v) => validarObligatorio(v, 'El SKU'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                decoration: _inputDecoration("Nombre del Producto", campo: 'nombre'),
                validator: (v) => validarObligatorio(v, 'El nombre'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _precioController,
                decoration: _inputDecoration("Precio de venta (S/)", campo: 'precio'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: validarPrecio,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: _inputDecoration("Stock Actual", campo: 'stock'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: validarStock,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _umbralController,
                decoration: _inputDecoration("Umbral de Alerta", campo: 'umbral'),
                keyboardType: TextInputType.number,
                validator: validarUmbral,
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
                  onPressed: _guardando ? null : _saveProduct,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

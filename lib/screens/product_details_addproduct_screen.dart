import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/products_model.dart';
import '../models/receipt_items_model.dart';
import '../services/product_service.dart';

class ProductSelectorModal extends StatefulWidget {
  final String receiptId;

  const ProductSelectorModal({super.key, required this.receiptId});

  // Método estático utilitario para invocar el modal de forma limpia desde la pantalla madre
  static Future<ReceiptItem?> show(BuildContext context, String receiptId) {
    return showModalBottomSheet<ReceiptItem>(
      context: context,
      isScrollControlled: true, // Permite que el teclado no tape el diseño
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSelectorModal(receiptId: receiptId),
    );
  }

  @override
  State<ProductSelectorModal> createState() => _ProductSelectorModalState();
}

class _ProductSelectorModalState extends State<ProductSelectorModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _costoController = TextEditingController();
  String _searchQuery = '';
  
  // Control de estado de expansión del ítem seleccionado
  String? _expandedProductId;
  double _selectedQuantity = 1.0;

  @override
  void dispose() {
    _searchController.dispose();
    _costoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // Mismo ratio h-[751px] del prototipo
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // --- HEADER: Título y Buscador ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Seleccionar Producto",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF191C1D)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF3F4944)),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Barra de Búsqueda con Scanner integrado
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF3F4944)),
                    hintText: "Buscar producto o SKU...",
                    filled: true,
                    fillColor: const Color(0xFFF3F4F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFBEC9C3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- BODY: Lista Reactiva alimentada por el Singleton ---
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: ProductService().productStream,
              initialData: ProductService().cachedProducts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && 
                   (snapshot.data == null || snapshot.data!.isEmpty)) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron productos en el catálogo", style: TextStyle(color: Colors.grey)),
                    );
                }

                // Filtrado reactivo en memoria RAM local
                final filtrados = snapshot.data!.where((prod) {
                  return prod.nombre.toLowerCase().contains(_searchQuery) ||
                         prod.id.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtrados.isEmpty) {
                  return const Center(
                    child: Text("No se encontraron productos en el catálogo", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    final product = filtrados[index];
                    final isExpanded = _expandedProductId == product.id;
                    final isLowStock = product.stock <= product.umbralAlerta;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isExpanded ? const Color(0xFF005440) : const Color(0xFFBEC9C3),
                          width: isExpanded ? 2 : 1,
                        ),
                        boxShadow: isExpanded 
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]
                            : null,
                      ),
                      child: Column(
                        children: [
                          // Fila Principal del Producto
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedProductId = null;
                                } else {
                                  _expandedProductId = product.id;
                                  _selectedQuantity = 1.0; // Resetea el contador
                                  _costoController.text = ''; // Resetea el costo
                                }
                              });
                            },
                            title: Text(
                              product.nombre,
                              style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF191C1D)),
                            ),
                            subtitle: Text(
                              "SKU: ${product.id}",
                              style: const TextStyle(color: Color(0xFF3F4944), fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Stock: ${product.stock.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                    color: isLowStock ? const Color(0xFFBA1A1A) : const Color(0xFF005440),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- CONTENIDO EXPANDIBLE (Subformulario de Cantidad) ---
                          if (isExpanded) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: const Color(0xFFF3F4F5),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Cantidad:", style: TextStyle(color: Color(0xFF3F4944))),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline),
                                            onPressed: _selectedQuantity > 1 
                                                ? () => setState(() => _selectedQuantity--)
                                                : null,
                                          ),
                                          SizedBox(
                                            width: 48,
                                            child: Text(
                                              _selectedQuantity.toStringAsFixed(0),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline),
                                            onPressed: () => setState(() => _selectedQuantity++),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Costo Unitario (S/.):", style: TextStyle(color: Color(0xFF3F4944))),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: _costoController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            border: OutlineInputBorder(),
                                            hintText: "0.00",
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Botón de Confirmación interna para empaquetar el ítem
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF005440),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text("Confirmar"),
                                onPressed: () {
                                  double costo = double.tryParse(_costoController.text) ?? 0.0;
                                  if (costo <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Ingrese un costo unitario válido')),
                                    );
                                    return;
                                  }

                                  // Instanciamos el ítem intermedio para mandarlo de regreso
                                  final newItem = ReceiptItem(
                                    id: 'ITEM-${DateTime.now().millisecondsSinceEpoch}',
                                    receiptId: widget.receiptId,
                                    productId: product.id, // ID relacional del catálogo
                                    cantidad: _selectedQuantity,
                                    costoUnitario: costo,
                                  );
                                  context.pop(newItem); // Cierra y retorna la data
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // --- FOOTER FIJO: Cancelar ---
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE1E3E4))),
              ),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFF6F7A74)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.pop(),
                child: const Text("Cancelar", style: TextStyle(color: Color(0xFF191C1D))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

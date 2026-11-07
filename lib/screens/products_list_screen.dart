import 'package:conectamarket/models/products_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/product_service.dart';
import '../../utils/validaciones.dart';
import '../../widgets_global/header_bar.dart';
import '../../widgets_global/base_card.dart';

class CatalogScreen extends StatelessWidget {
  final ProductService _service = ProductService();

  CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBarWidget(
        title: "Inventario",
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.teal),
            tooltip: 'Importar CSV',
            onPressed: () {
              context.push('/import-csv');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF005440),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Agregar producto',
        onPressed: () {
          context.push('/product-details');
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Product>>(
          stream: _service.productStream,
          initialData: _service.cachedProducts,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              // Si no hay datos en caché y el stream aún no emite, mostramos carga.
              return const Center(child: CircularProgressIndicator());
            }

            final products = snapshot.data!;
            if (products.isEmpty) {
              return const _CatalogoVacio();
            }
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return BaseCardWidget(
                  title: p.nombre,
                  subtitle: "SKU: ${p.id} · S/ ${p.precio.toStringAsFixed(2)}",
                  priceOrStatus: "Stock: ${formatoCantidad(p.stock)} un.",
                  statusLabel: p.stock <= p.umbralAlerta ? "STOCK BAJO" : "DISPONIBLE",
                  statusColor: p.stock <= p.umbralAlerta ? Colors.orange : Colors.green,
                  onTap: () {
                    // Navegación a detalles en modo edición
                    context.push(
                      '/product-details',
                      extra: p,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CatalogoVacio extends StatelessWidget {
  const _CatalogoVacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFF6F7A74)),
            SizedBox(height: 16),
            Text(
              "Aún no tienes productos. Toca + para agregar el primero.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF3F4944)),
            ),
            SizedBox(height: 8),
            Text(
              "También puedes importarlos desde un archivo CSV con el botón de la parte superior.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6F7A74)),
            ),
          ],
        ),
      ),
    );
  }
}

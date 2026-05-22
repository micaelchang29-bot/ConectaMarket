import 'package:conectamarket/models/products_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/product_service.dart';
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
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return BaseCardWidget(
                  title: p.nombre,
                  subtitle: "SKU: ${p.id}",
                  priceOrStatus: "Stock: ${p.stock.toString()} un.", 
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
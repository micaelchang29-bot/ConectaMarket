import 'package:flutter/material.dart';
import 'dashboard_ui_helpers.dart';

class FeaturedProductsSection extends StatelessWidget {
  final String title;
  final Future<Map<String, dynamic>> future;
  final String emptyMessage;

  const FeaturedProductsSection({
    super.key,
    required this.title,
    required this.future,
    this.emptyMessage = "No hay datos de productos disponibles aún",
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildBanner(
                color: const Color(0xFFFFEBEE),
                borderColor: const Color(0xFFEF5350),
                icon: Icons.error_outline,
                iconColor: const Color(0xFFBA1A1A),
                message: "Error cargando productos: ${snapshot.error}",
                textColor: const Color(0xFFBA1A1A),
              );
            }

            final data = snapshot.data ?? {};
            final mostSold = (data['most_sold'] as Map?) ?? {};
            final mostProfitable = (data['most_profitable'] as Map?) ?? {};

            if (mostSold.isEmpty && mostProfitable.isEmpty) {
              return _buildBanner(
                color: const Color(0xFFFFF3E0),
                borderColor: const Color(0xFFFFB74D),
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFF57F17),
                message: emptyMessage,
                textColor: const Color(0xFF704200),
              );
            }

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                buildProductCard(
                  title: "Más Vendido",
                  productName: mostSold.isNotEmpty ? (mostSold['nombre'] ?? "—") : "Sin datos",
                  value: mostSold.isNotEmpty ? "${(mostSold['total_quantity'] as num?)?.toInt() ?? 0} unidades" : "—",
                  icon: Icons.trending_up,
                  color: const Color(0xFF0F6E56),
                ),
                buildProductCard(
                  title: "Más Rentable",
                  productName: mostProfitable.isNotEmpty ? (mostProfitable['nombre'] ?? "—") : "Sin datos",
                  value: mostProfitable.isNotEmpty
                      ? "S/ ${(mostProfitable['ganancia'] as num?)?.toStringAsFixed(2) ?? "0.00"}"
                      : "—",
                  icon: Icons.monetization_on,
                  color: const Color(0xFF005440),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBanner({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String message,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: textColor))),
        ],
      ),
    );
  }
}

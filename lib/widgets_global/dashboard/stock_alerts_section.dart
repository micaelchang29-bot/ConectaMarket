import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/products_model.dart';
import '../../models/receipts_model.dart';
import '../../services/dashboard_service.dart';
import '../../services/product_service.dart';
import '../../services/receipt_service.dart';

class StockAlertsSection extends StatefulWidget {
  const StockAlertsSection({super.key});

  @override
  State<StockAlertsSection> createState() => _StockAlertsSectionState();
}

class _StockAlertsSectionState extends State<StockAlertsSection> {
  late Future<List<Map<String, dynamic>>> _future;

  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<List<Receipt>>? _receiptSub;

  @override
  void initState() {
    super.initState();
    _future = DashboardAiService().getLowStockAlerts();

    _productSub = ProductService().productStream.listen((_) => _recalculate());
    _receiptSub = ReceiptService().receiptStream.listen((_) => _recalculate());
  }

  void _recalculate() {
    if (!mounted) return;
    setState(() {
      _future = DashboardAiService().getLowStockAlerts();
    });
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _receiptSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _buildBanner(
            color: const Color(0xFFFFEBEE),
            borderColor: const Color(0xFFEF5350),
            icon: Icons.error_outline,
            iconColor: const Color(0xFFBA1A1A),
            message: "Error cargando alertas: ${snapshot.error}",
            textColor: const Color(0xFFBA1A1A),
          );
        }

        final lowStockProducts = snapshot.data ?? [];

        if (lowStockProducts.isEmpty) {
          return _buildBanner(
            color: const Color(0xFFE8F5E9),
            borderColor: const Color(0xFFC8E6C9),
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF2E7D32),
            message: "Todos los productos tienen stock saludable",
            textColor: const Color(0xFF2E7D32),
          );
        }

        return Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E3E4)),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: lowStockProducts.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE1E3E4), indent: 56),
            itemBuilder: (context, index) {
              final product = lowStockProducts[index];
              final String productName = product['nombre'] ?? '—';
              final double stock = (product['stock'] as num?)?.toDouble() ?? 0;
              final int umbralAlerta = (product['umbralAlerta'] as num?)?.toInt() ?? 5;
              final int unidadesFaltantes = (product['unidadesFaltantes'] as num?)?.toInt() ?? 0;
              final String estadoStock = product['estadoStock'] ?? 'Bajo';

              final (bgColor, textColor, icon) = _alertStyle(estadoStock);

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                      child: Icon(icon, color: textColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stock: ${stock.toStringAsFixed(0)} / Umbral: $umbralAlerta (Faltan: $unidadesFaltantes)',
                            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        estadoStock,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  (Color, Color, IconData) _alertStyle(String estadoStock) {
    switch (estadoStock) {
      case 'Agotado':
        return (const Color(0xFFFFDAD6), const Color(0xFF93000a), Icons.error);
      case 'Crítico':
        return (const Color(0xFFFFDAD6), const Color(0xFFBA1A1A), Icons.warning);
      default:
        return (const Color(0xFFFFDCBB), const Color(0xFF704200), Icons.info_outline);
    }
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

import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';

class InventoryRiskSection extends StatelessWidget {
  const InventoryRiskSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DashboardAiService().getInventoryRiskClassification(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildContainer(child: const Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _buildContainer(
            child: Center(
              child: Text(
                "Error cargando estado: ${snapshot.error}",
                style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
              ),
            ),
          );
        }

        final riskMetrics = snapshot.data ?? [];

        if (riskMetrics.isEmpty) {
          return _buildContainer(
            child: const Center(
              child: Text(
                "No hay productos registrados",
                style: TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
              ),
            ),
          );
        }

        return _buildContainer(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: riskMetrics.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE1E3E4)),
            itemBuilder: (context, index) {
              final metric = riskMetrics[index];
              final String productName = metric['nombre'] ?? '—';
              final double stock = (metric['stock'] as num?)?.toDouble() ?? 0;
              final int rotationDays = (metric['rotation_days'] as num?)?.toInt() ?? 0;
              final String riskLevel = metric['risk_level'] ?? 'DESCONOCIDO';
              final int suggestedQty = (metric['suggested_qty'] as num?)?.toInt() ?? 0;

              final (bgColor, textColor, badgeColor, icon) = _riskStyle(riskLevel);

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
                            'Stock: ${stock.toStringAsFixed(0)} / Cobertura: $rotationDays días',
                            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (suggestedQty > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Comprar: $suggestedQty u. (cubre 30 días)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        border: Border.all(color: badgeColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        riskLevel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
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

  Widget _buildContainer({required Widget child}) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: child,
    );
  }

  (Color, Color, Color, IconData) _riskStyle(String riskLevel) {
    switch (riskLevel) {
      case 'BAJO':
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), const Color(0xFF4CAF50), Icons.check_circle);
      case 'MEDIO':
        return (const Color(0xFFFFF3E0), const Color(0xFFF57F17), const Color(0xFFFFB74D), Icons.info);
      case 'ALTO':
        return (const Color(0xFFFFDCBB), const Color(0xFF704200), const Color(0xFFFFB74D), Icons.warning);
      default: // CRÍTICO
        return (const Color(0xFFFFDAD6), const Color(0xFF93000a), const Color(0xFFBA1A1A), Icons.error);
    }
  }
}

import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';

class InventoryRiskSection extends StatelessWidget {
  const InventoryRiskSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: DashboardAiService().getInventoryRiskReport(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildContainer(child: const Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _buildContainer(
            child: Center(
              child: Text(
                "No se pudo calcular el estado del inventario.",
                style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
              ),
            ),
          );
        }

        final riskMetrics = List<Map<String, dynamic>>.from(snapshot.data?['items'] ?? const []);
        final sinHistorial = List<Map<String, dynamic>>.from(snapshot.data?['sin_historial'] ?? const []);

        if (riskMetrics.isEmpty && sinHistorial.isEmpty) {
          return _buildContainer(
            child: const Center(
              child: Text(
                "No hay productos registrados",
                style: TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
              ),
            ),
          );
        }

        final int aviso = sinHistorial.isEmpty ? 0 : 1;
        return _buildContainer(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: aviso + riskMetrics.length + sinHistorial.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE1E3E4)),
            itemBuilder: (context, index) {
              if (index < aviso) return _buildAvisoSinHistorial(sinHistorial.length);
              if (index >= aviso + riskMetrics.length) {
                return _buildSinHistorial(sinHistorial[index - aviso - riskMetrics.length]);
              }
              final metric = riskMetrics[index - aviso];
              final String productName = metric['nombre'] ?? '—';
              final double stock = (metric['stock'] as num?)?.toDouble() ?? 0;
              final int rotationDays = (metric['rotation_days'] as num?)?.toInt() ?? 0;
              final String riskLevel = metric['risk_level'] ?? 'DESCONOCIDO';
              final int suggestedQty = (metric['suggested_qty'] as num?)?.toInt() ?? 0;
              final int weeklyDemand = ((metric['weekly_demand'] as num?)?.toDouble() ?? 0).round();

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
                          const SizedBox(height: 2),
                          Text(
                            'Demanda estimada próxima semana: $weeklyDemand u.',
                            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            suggestedQty > 0
                                ? 'Comprar: $suggestedQty u. (cubre 30 días)'
                                : 'No requiere reabastecimiento (sugerido: 0 u.)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
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

  Widget _buildAvisoSinHistorial(int cantidad) {
    return Container(
      color: const Color(0xFFF1F3F4),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF5F6368), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$cantidad ${cantidad == 1 ? 'producto' : 'productos'} sin historial suficiente '
              '(menos de ${DashboardAiService.minDiasHistorial} días de ventas): no se estima su demanda.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinHistorial(Map<String, dynamic> p) {
    final int dias = (p['dias_con_ventas'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Color(0xFFF1F3F4), shape: BoxShape.circle),
            child: const Icon(Icons.hourglass_empty, color: Color(0xFF5F6368), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['nombre']?.toString() ?? '—',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Historial insuficiente: $dias ${dias == 1 ? 'día' : 'días'} con ventas '
                  '(se necesitan ${DashboardAiService.minDiasHistorial})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              border: Border.all(color: const Color(0xFF9AA0A6)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'SIN DATOS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5F6368)),
            ),
          ),
        ],
      ),
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

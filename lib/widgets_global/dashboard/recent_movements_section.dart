import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';

class RecentMovementsSection extends StatelessWidget {
  const RecentMovementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DashboardAiService().getRecentMovements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildContainer(child: const Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _buildContainer(
            child: Center(
              child: Text(
                "Error cargando movimientos: ${snapshot.error}",
                style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
              ),
            ),
          );
        }

        final movements = snapshot.data ?? [];

        if (movements.isEmpty) {
          return _buildContainer(
            child: const Center(
              child: Text(
                "No hay movimientos registrados",
                style: TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
              ),
            ),
          );
        }

        return _buildContainer(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: movements.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE1E3E4), indent: 56),
            itemBuilder: (context, index) {
              final movement = movements[index];
              final String productName = movement['nombre'] ?? '—';
              final double cantidad = (movement['cantidad'] as num?)?.toDouble() ?? 0;
              final String fecha = movement['fecha'] ?? '—';
              final int tipoMovimiento = (movement['tipomovimiento'] as num?)?.toInt() ?? 0;

              final bool isEntrada = tipoMovimiento == 0;
              final Color bgIcon = isEntrada ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
              final Color colorIcon = isEntrada ? const Color(0xFF005440) : const Color(0xFFC62828);
              final IconData icon = isEntrada ? Icons.add : Icons.remove;
              final String displayText = isEntrada
                  ? "+${cantidad.toStringAsFixed(0)} $productName"
                  : "-${cantidad.toStringAsFixed(0)} $productName";

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: bgIcon, shape: BoxShape.circle),
                            child: Icon(icon, color: colorIcon, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayText,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  fecha,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.cloud_done_outlined, color: Color(0xFFBEC9C3), size: 20),
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
}

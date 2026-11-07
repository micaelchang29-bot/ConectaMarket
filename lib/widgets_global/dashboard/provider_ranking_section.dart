import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';
import '../../services/provider_service.dart';

class ProviderRankingSection extends StatelessWidget {
  const ProviderRankingSection({super.key});

  static const _medals = ['🥇', '🥈', '🥉', '⭐'];
  static const _bgColors = [
    Color(0xFFFFEAD6),
    Color(0xFFEDEDED),
    Color(0xFFFFF3CD),
    Color(0xFFE8EAF6),
  ];
  static const _textColors = [
    Color(0xFF805100),
    Color(0xFF424242),
    Color(0xFF856404),
    Color(0xFF283593),
  ];

  /// Ranking y, a la vez, la lista de proveedores (para los que no tienen historial).
  Future<List<Map<String, dynamic>>> _cargar() async {
    final resultados = await Future.wait([
      DashboardAiService().getProviderRanking(),
      ProviderService().refreshProviders(),
    ]);
    return resultados.first as List<Map<String, dynamic>>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cargar(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final providers = snapshot.data ?? [];
        final rankeados = providers.map((p) => p['id']).toSet();
        final sinHistorial = ProviderService()
            .cachedProviders
            .where((p) => !rankeados.contains(p.id))
            .map((p) => p.nombre)
            .toList()
          ..sort();

        if (providers.isEmpty) {
          final aviso = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF57F17)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "No hay histórico de proveedores en los últimos 12 meses",
                    style: TextStyle(fontSize: 12, color: Color(0xFF704200)),
                  ),
                ),
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [aviso, if (sinHistorial.isNotEmpty) _buildSinHistorial(sinHistorial)],
          );
        }

        // Se muestran todos los proveedores con historial, ordenados por puntaje
        final int displayCount = providers.length;

        final grid = GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: List.generate(displayCount, (index) {
            final provider = providers[index];
            final String name = provider['nombre'] ?? '—';
            final int score = (provider['global_score'] as num?)?.toInt() ?? 0;
            final String recommendation = provider['recommendation'] ?? '';
            final int compras = (provider['num_compras'] as num?)?.toInt() ?? 0;
            final int estilo = index < _bgColors.length ? index : _bgColors.length - 1;
            final Color bg = _bgColors[estilo];
            final Color tc = _textColors[estilo];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tc.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_medals[estilo], style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$score/100",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tc),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tc.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$compras compras",
                        style: TextStyle(fontSize: 10, color: tc.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [grid, if (sinHistorial.isNotEmpty) _buildSinHistorial(sinHistorial)],
        );
      },
    );
  }

  /// Proveedores sin compras en los últimos 12 meses: se listan sin puntaje.
  Widget _buildSinHistorial(List<String> nombres) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDADCE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sin historial suficiente (sin puntaje)",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3F4944)),
          ),
          const SizedBox(height: 4),
          const Text(
            "Aún no tienen compras registradas en los últimos 12 meses.",
            style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: nombres
                .map((n) => Chip(
                      label: Text(n, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

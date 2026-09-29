import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DashboardAiService().getProviderRanking(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final providers = snapshot.data ?? [];

        if (providers.isEmpty) {
          return Container(
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
        }

        final int displayCount = providers.length > 4 ? 4 : providers.length;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: List.generate(displayCount, (index) {
            final provider = providers[index];
            final String name = provider['nombre'] ?? '—';
            final double score = (provider['global_score'] as num?)?.toDouble() ?? 0;
            final String recommendation = provider['recommendation'] ?? '';
            final int compras = (provider['num_compras'] as num?)?.toInt() ?? 0;
            final Color bg = _bgColors[index];
            final Color tc = _textColors[index];

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
                      Text(_medals[index], style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${score.toStringAsFixed(1)}/100",
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
      },
    );
  }
}

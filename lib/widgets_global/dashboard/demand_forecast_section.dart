import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';

class DemandForecastSection extends StatelessWidget {
  final String productId;

  const DemandForecastSection({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<double>>(
      future: DashboardAiService().predictWeeklyDemand(productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<double> predictionVector = snapshot.data ?? [2.0, 2.0, 3.0, 2.0, 4.0, 3.0, 5.0];
        final double maxDemand = predictionVector.reduce(max);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E3E4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final double value = predictionVector[index];
              final double calculatedHeight = maxDemand > 0 ? (value / maxDemand) * 120 : 20.0;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF005440)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 24,
                    height: max(calculatedHeight, 8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F6E56),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Día ${index + 1}",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF3F4944), fontWeight: FontWeight.w500),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

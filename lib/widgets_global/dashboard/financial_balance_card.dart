import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/receipt_service.dart';
import '../month_selector_widget.dart';
import 'dashboard_ui_helpers.dart';

class FinancialBalanceCard extends StatefulWidget {
  const FinancialBalanceCard({super.key});

  @override
  State<FinancialBalanceCard> createState() => _FinancialBalanceCardState();
}

class _FinancialBalanceCardState extends State<FinancialBalanceCard> {
  int _selectedYear = 2026;
  int _selectedMonth = 5;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBEC9C3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Balance del Período",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MonthSelectorWidget(
            initialYear: _selectedYear,
            initialMonth: _selectedMonth,
            onMonthChanged: (year, month) {
              setState(() {
                _selectedYear = year;
                _selectedMonth = month;
              });
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, dynamic>>(
            future: ReceiptService().getFinancialBalance(year: _selectedYear, month: _selectedMonth),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text("Error: ${snapshot.error}", style: const TextStyle(color: Color(0xFFBA1A1A)));
              }

              final data = snapshot.data ?? {};
              final double ingresos = (data['total_ventas'] ?? 0.0).toDouble();
              final double egresos = (data['total_compras'] ?? 0.0).toDouble();
              final double balanceNeto = (data['balance_neto'] ?? 0.0).toDouble();
              final List<double> vectorVentas = List<double>.from(data['vector_ventas'] ?? []);
              final List<double> vectorCompras = List<double>.from(data['vector_compras'] ?? []);
              final List<String> etiquetasX = List<String>.from(data['etiquetas_x'] ?? []);

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: buildKpi("Ingresos", ingresos, const Color(0xFF0F6E56))),
                      const SizedBox(width: 8),
                      Expanded(child: buildKpi("Egresos", egresos, const Color(0xFF3F4944))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: buildKpi(
                          "Balance Neto",
                          balanceNeto,
                          balanceNeto >= 0 ? const Color(0xFF0F6E56) : const Color(0xFFBA1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(etiquetasX.length, (index) {
                        final double venta = vectorVentas.length > index ? vectorVentas[index] : 0.0;
                        final double compra = vectorCompras.length > index ? vectorCompras[index] : 0.0;

                        final double maxVenta = vectorVentas.isNotEmpty ? vectorVentas.reduce(max) : 0;
                        final double maxCompra = vectorCompras.isNotEmpty ? vectorCompras.reduce(max) : 0;
                        final double maxMonto = max(maxVenta, maxCompra) > 0 ? max(maxVenta, maxCompra) : 1.0;

                        final double alturaVenta = (venta / maxMonto) * 100;
                        final double alturaCompra = (compra / maxMonto) * 100;

                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 12,
                                    height: max(alturaVenta, 4.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F6E56),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Container(
                                    width: 12,
                                    height: max(alturaCompra, 4.0),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: Border.all(color: const Color(0xFFBEC9C3), width: 1.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                etiquetasX[index],
                                style: const TextStyle(fontSize: 10, color: Color(0xFF3F4944)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

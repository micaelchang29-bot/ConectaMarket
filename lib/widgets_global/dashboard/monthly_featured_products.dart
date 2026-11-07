import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';
import '../month_selector_widget.dart';
import 'featured_products_section.dart';

/// Más vendido y más rentable del mes elegido; abre en el mes actual.
class MonthlyFeaturedProducts extends StatefulWidget {
  const MonthlyFeaturedProducts({super.key});

  @override
  State<MonthlyFeaturedProducts> createState() => _MonthlyFeaturedProductsState();
}

class _MonthlyFeaturedProductsState extends State<MonthlyFeaturedProducts> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = DashboardAiService().getProductInsightsForMonth(_year, _month);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeaturedProductsSection(
          title: "Productos Destacados",
          future: _future,
          emptyMessage: "No hay ventas registradas en este mes",
          encabezado: MonthSelectorWidget(
            initialYear: _year,
            initialMonth: _month,
            onMonthChanged: (y, m) => setState(() {
              _year = y;
              _month = m;
              _cargar();
            }),
          ),
        ),
      ],
    );
  }
}

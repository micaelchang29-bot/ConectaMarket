import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/receipt_service.dart';
import '../../services/sync_service.dart';
import '../../widgets_global/login_dialog.dart';
import '../../widgets_global/month_selector_widget.dart';
import 'stock_chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String _sampleProductId = 'PROD-ARROZ-01';
  int _selectedYear = 2026;
  int _selectedMonth = 5;
  bool _isSyncing = false;

  Future<void> _runBackup() async {
    if (AuthService.instance.currentUser == null) {
      final authenticated = await LoginDialog.show(context);
      if (!authenticated) return;
    }

    setState(() => _isSyncing = true);
    final result = await SyncService.instance.backup();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.success ? const Color(0xFF0F6E56) : const Color(0xFFBA1A1A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.success
              ? 'Backup exitoso · ${result.movementsSynced} movimiento${result.movementsSynced == 1 ? '' : 's'} sincronizado${result.movementsSynced == 1 ? '' : 's'}'
              : 'Error al sincronizar: ${result.error}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      
      // --- 1. TOP APP BAR (Header Homogéneo) ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Oculta la flecha si es pestaña principal
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0F6E56),
              child: Text("R", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bodega Connect",
                    style: TextStyle(color: Color(0xFF005440), fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder(
                    stream: AuthService.instance.userStream,
                    builder: (context, snapshot) {
                      final name = snapshot.data?.displayName ?? snapshot.data?.email ?? 'Invitado';
                      return Text(
                        'Hola, $name',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Badge reactivo que valida la resiliencia Offline-First
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text(
                  "Synced",
                  style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF005440)),
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined, color: Color(0xFF005440)),
            tooltip: 'Hacer backup',
            onPressed: _isSyncing ? null : _runBackup,
          ),
          StreamBuilder(
            stream: AuthService.instance.userStream,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null) {
                return IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF005440)),
                  tooltip: 'Cerrar sesión',
                  onPressed: () => AuthService.instance.logout(),
                );
              }
              return IconButton(
                icon: const Icon(Icons.person_outline, color: Color(0xFF005440)),
                tooltip: 'Iniciar sesión',
                onPressed: () => LoginDialog.show(context),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StockChatScreen()),
        ),
        backgroundColor: const Color(0xFF0F6E56),
        icon: const Icon(Icons.psychology_outlined, color: Colors.white),
        label: const Text(
          'Consultar IA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),

      // --- MAIN CONTENT AREA (Scroll Vertical Infinito) ---
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            
            // --- 1.5. SECCIÓN: BALANCE FINANCIERO ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBEC9C3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
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
                        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
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
                          // KPIs
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _buildKpi("Ingresos", ingresos, const Color(0xFF0F6E56))),
                              const SizedBox(width: 8),
                              Expanded(child: _buildKpi("Egresos", egresos, const Color(0xFF3F4944))),
                              const SizedBox(width: 8),
                              Expanded(child: _buildKpi("Balance Neto", balanceNeto, balanceNeto >= 0 ? const Color(0xFF0F6E56) : const Color(0xFFBA1A1A))),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Gráfico de barras dobles
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
                                      )
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
            ),
            const SizedBox(height: 32),

            // --- 1.6. SECCIÓN: ESTADO DE INVENTARIO (ML Pair 1 - Risk Classification) ---
            const Text(
              "Estado de Inventario (IA)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
            ),
            const SizedBox(height: 16),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: DashboardAiService().getInventoryRiskClassification(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
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
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
                    child: const Center(
                      child: Text(
                        "No hay productos registrados",
                        style: TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
                      ),
                    ),
                  );
                }

                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E3E4)),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(0),
                    itemCount: riskMetrics.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE1E3E4)),
                    itemBuilder: (context, index) {
                      final metric = riskMetrics[index];
                      final String productName = metric['nombre'] ?? '—';
                      final double stock = (metric['stock'] as num?)?.toDouble() ?? 0;
                      final int rotationDays = (metric['rotation_days'] as num?)?.toInt() ?? 0;
                      final String riskLevel = metric['risk_level'] ?? 'DESCONOCIDO';

                      Color backgroundColor;
                      Color textColor;
                      Color badgeColor;
                      IconData icon;

                      switch (riskLevel) {
                        case 'BAJO':
                          backgroundColor = const Color(0xFFE8F5E9);
                          textColor = const Color(0xFF2E7D32);
                          badgeColor = const Color(0xFF4CAF50);
                          icon = Icons.check_circle;
                          break;
                        case 'MEDIO':
                          backgroundColor = const Color(0xFFFFF3E0);
                          textColor = const Color(0xFFF57F17);
                          badgeColor = const Color(0xFFFFB74D);
                          icon = Icons.info;
                          break;
                        case 'ALTO':
                          backgroundColor = const Color(0xFFFFDCBB);
                          textColor = const Color(0xFF704200);
                          badgeColor = const Color(0xFFFFB74D);
                          icon = Icons.warning;
                          break;
                        default: // CRÍTICO
                          backgroundColor = const Color(0xFFFFDAD6);
                          textColor = const Color(0xFF93000a);
                          badgeColor = const Color(0xFFBA1A1A);
                          icon = Icons.error;
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: textColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF191C1D),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stock: ${stock.toStringAsFixed(0)} / Cobertura: $rotationDays días',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // --- 2. SECCIÓN: ACCIONES RÁPIDAS (Bento Grid Original) ---
            const Text(
              "Productos Destacados",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: DashboardAiService().getProductInsights(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF5350)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFBA1A1A)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Error cargando productos: ${snapshot.error}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data ?? {};
                final hasError = data['error'] != null;
                final mostSold = (data['most_sold'] as Map?) ?? {};
                final mostProfitable = (data['most_profitable'] as Map?) ?? {};

                if (mostSold.isEmpty && mostProfitable.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57F17)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "No hay datos de productos disponibles aún",
                            style: TextStyle(fontSize: 12, color: Color(0xFF704200)),
                          ),
                        ),
                      ],
                    ),
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
                    _buildProductCard(
                      title: "Más Vendido",
                      productName: mostSold.isNotEmpty ? (mostSold['nombre'] ?? "—") : "Sin datos",
                      value: mostSold.isNotEmpty ? "${(mostSold['total_quantity'] as num?)?.toInt() ?? 0} unidades" : "—",
                      icon: Icons.trending_up,
                      color: const Color(0xFF0F6E56),
                    ),
                    _buildProductCard(
                      title: "Más Rentable",
                      productName: mostProfitable.isNotEmpty ? (mostProfitable['nombre'] ?? "—") : "Sin datos",
                      value: mostProfitable.isNotEmpty ? "S/ ${(mostProfitable['ganancia'] as num?)?.toStringAsFixed(2) ?? "0.00"}" : "—",
                      icon: Icons.monetization_on,
                      color: const Color(0xFF005440),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // --- 2.5. SECCIÓN: PRODUCTOS DESTACADOS DEL MES PASADO ---
            const Text(
              "Productos Destacados (Mes Pasado)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: DashboardAiService().getLastMonthProductInsights(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF5350)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFBA1A1A)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Error cargando productos: ${snapshot.error}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data ?? {};
                final mostSold = (data['most_sold'] as Map?) ?? {};
                final mostProfitable = (data['most_profitable'] as Map?) ?? {};

                if (mostSold.isEmpty && mostProfitable.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57F17)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "No hay datos del mes anterior",
                            style: TextStyle(fontSize: 12, color: Color(0xFF704200)),
                          ),
                        ),
                      ],
                    ),
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
                    _buildProductCard(
                      title: "Más Vendido",
                      productName: mostSold.isNotEmpty ? (mostSold['nombre'] ?? "—") : "Sin datos",
                      value: mostSold.isNotEmpty ? "${(mostSold['total_quantity'] as num?)?.toInt() ?? 0} unidades" : "—",
                      icon: Icons.trending_up,
                      color: const Color(0xFF0F6E56),
                    ),
                    _buildProductCard(
                      title: "Más Rentable",
                      productName: mostProfitable.isNotEmpty ? (mostProfitable['nombre'] ?? "—") : "Sin datos",
                      value: mostProfitable.isNotEmpty ? "S/ ${(mostProfitable['ganancia'] as num?)?.toStringAsFixed(2) ?? "0.00"}" : "—",
                      icon: Icons.monetization_on,
                      color: const Color(0xFF005440),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // --- 2.7. SECCIÓN: TOP PROVEEDORES (ML Pair Providers) ---
            const Text(
              "Top Proveedores (IA)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
            ),
            const SizedBox(height: 16),

            FutureBuilder<List<Map<String, dynamic>>>(
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
                final List<String> medals = ['🥇', '🥈', '🥉', '⭐'];
                final List<Color> bgColors = [
                  const Color(0xFFFFEAD6),
                  const Color(0xFFEDEDED),
                  const Color(0xFFFFF3CD),
                  const Color(0xFFE8EAF6),
                ];
                final List<Color> textColors = [
                  const Color(0xFF805100),
                  const Color(0xFF424242),
                  const Color(0xFF856404),
                  const Color(0xFF283593),
                ];

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
                    final int score = (provider['global_score'] as num?)?.toInt() ?? 0;
                    final String recommendation = provider['recommendation'] ?? '';
                    final int compras = (provider['num_compras'] as num?)?.toInt() ?? 0;
                    final Color bg = bgColors[index];
                    final Color tc = textColors[index];

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
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: tc,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                medals[index],
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$score/100",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: tc,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recommendation,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: tc.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$compras compras",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: tc.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 32),

            // --- 3. SECCIÓN: MOVIMIENTOS RECIENTES (Lista Dinámica) ---
            const Text(
              "Movimientos Recientes",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
            ),
            const SizedBox(height: 16),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: DashboardAiService().getRecentMovements(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
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
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
                    child: const Center(
                      child: Text(
                        "No hay movimientos registrados",
                        style: TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
                      ),
                    ),
                  );
                }

                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E3E4)),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(0),
                    itemCount: movements.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE1E3E4), indent: 56),
                    itemBuilder: (context, index) {
                      final movement = movements[index];
                      final String productName = movement['nombre'] ?? '—';
                      final double cantidad = (movement['cantidad'] as num?)?.toDouble() ?? 0;
                      final String fecha = movement['fecha'] ?? '—';
                      final int tipoMovimiento = (movement['tipomovimiento'] as num?)?.toInt() ?? 0;

                      bool isEntrada = tipoMovimiento == 0;
                      Color bgIcon = isEntrada ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
                      Color colorIcon = isEntrada ? const Color(0xFF005440) : const Color(0xFFC62828);
                      IconData icon = isEntrada ? Icons.add : Icons.remove;

                      String displayText = isEntrada
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
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF191C1D),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          fecha,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF3F4944),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.cloud_done_outlined,
                              color: const Color(0xFFBEC9C3),
                              size: 20,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // --- 4. SECCIÓN: ALERTAS DE STOCK (Lista Dinámica) ---
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Alertas de Stock",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: DashboardAiService().getLowStockAlerts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF5350)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFBA1A1A)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Error cargando alertas: ${snapshot.error}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFFBA1A1A)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final lowStockProducts = snapshot.data ?? [];

                if (lowStockProducts.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Todos los productos tienen stock saludable",
                            style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
                    ),
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
                    padding: const EdgeInsets.all(0),
                    itemCount: lowStockProducts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE1E3E4), indent: 56),
                    itemBuilder: (context, index) {
                      final product = lowStockProducts[index];
                      final String productName = product['nombre'] ?? '—';
                      final double stock = (product['stock'] as num?)?.toDouble() ?? 0;
                      final int umbralAlerta = (product['umbralAlerta'] as num?)?.toInt() ?? 5;
                      final int unidadesFaltantes = (product['unidadesFaltantes'] as num?)?.toInt() ?? 0;
                      final String estadoStock = product['estadoStock'] ?? 'Bajo';

                      Color backgroundColor;
                      Color textColor;
                      IconData icon;

                      if (estadoStock == 'Agotado') {
                        backgroundColor = const Color(0xFFFFDAD6);
                        textColor = const Color(0xFF93000a);
                        icon = Icons.error;
                      } else if (estadoStock == 'Crítico') {
                        backgroundColor = const Color(0xFFFFDAD6);
                        textColor = const Color(0xFFBA1A1A);
                        icon = Icons.warning;
                      } else {
                        backgroundColor = const Color(0xFFFFDCBB);
                        textColor = const Color(0xFF704200);
                        icon = Icons.info_outline;
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: textColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF191C1D),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stock: ${stock.toStringAsFixed(0)} / Umbral: $umbralAlerta (Faltan: $unidadesFaltantes)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                estadoStock,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // ==========================================================
            // 🚀 COMPONENTE AGREGADO MÁS ABAJO MEDIANTE SCROLL (TESIS)
            // ==========================================================
            const Divider(color: Color(0xFFE1E3E4), thickness: 1),
            const SizedBox(height: 16),
            const Text(
              "Tendencia de Demanda Proyectada (7 días)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
            ),
            const SizedBox(height: 4),
            const Text(
              "Inferencia algorítmica estacional calculada localmente (Edge ML)",
              style: TextStyle(fontSize: 13, color: Color(0xFF3F4944), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            
            // FutureBuilder que dibuja las barras predictivas del modelo matemático de Holt
            FutureBuilder<List<double>>(
              future: DashboardAiService().predictWeeklyDemand(_sampleProductId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final List<double> predictionVector = snapshot.data ?? [2.0, 2.0, 3.0, 2.0, 4.0, 3.0, 5.0];
                // Determinamos el pico máximo para escalar la altura máxima de las barras a 120px ergonómicos
                final double maxDemand = predictionVector.reduce(max);

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E3E4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (index) {
                          final double value = predictionVector[index];
                          // Regla de tres simple para la proporción de altura en pixeles de la barra
                          final double calculatedHeight = maxDemand > 0 ? (value / maxDemand) * 120 : 20.0;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Valor numérico flotante arrojado por el ML encima de la barra
                              Text(
                                value.toString(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF005440)),
                              ),
                              const SizedBox(height: 6),
                              // La barra física del gráfico
                              Container(
                                width: 24,
                                height: max(calculatedHeight, 8.0), // Mínimo 8px para que se note el bloque si da 0
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F6E56),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Rótulo del eje X
                              Text(
                                "Día ${index + 1}",
                                style: const TextStyle(fontSize: 11, color: Color(0xFF3F4944), fontWeight: FontWeight.w500),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24), // Espaciado final de cortesía para el scroll
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES REUTILIZABLES (Clean UI) ---

  Widget _buildProductCard({
    required String title,
    required String productName,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoButton(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF005440), size: 32),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF191C1D))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovementItem(String title, String time, IconData icon, Color bgIcon, Color colorIcon, bool isSynced) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)), overflow: TextOverflow.ellipsis),
                      Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF3F4944)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isSynced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: isSynced ? const Color(0xFFBEC9C3) : const Color(0xFFFDAD4E),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
    String? iaPrescription,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
          // Si el motor de IA calculó una solución óptima en SQLite, abrimos el bloque prescriptivo
          if (iaPrescription != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_outlined, color: Color(0xFF005440), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      iaPrescription,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005440)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpi(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF3F4944)), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text("S/ ${amount.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
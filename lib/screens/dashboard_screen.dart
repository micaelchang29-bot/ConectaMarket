import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/sync_service.dart';
import '../../widgets_global/login_dialog.dart';
import '../../widgets_global/dashboard/financial_balance_card.dart';
import '../../widgets_global/dashboard/inventory_risk_section.dart';
import '../../widgets_global/dashboard/featured_products_section.dart';
import '../../widgets_global/dashboard/provider_ranking_section.dart';
import '../../widgets_global/dashboard/recent_movements_section.dart';
import '../../widgets_global/dashboard/stock_alerts_section.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
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
        onPressed: () => context.push('/stock-chat'),
        backgroundColor: const Color(0xFF0F6E56),
        icon: const Icon(Icons.psychology_outlined, color: Colors.white),
        label: const Text('Consultar IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const FinancialBalanceCard(),
            const SizedBox(height: 32),

            FeaturedProductsSection(
              title: "Productos Destacados",
              future: DashboardAiService().getProductInsights(),
            ),
            const SizedBox(height: 32),

            FeaturedProductsSection(
              title: "Productos Destacados (Mes Pasado)",
              future: DashboardAiService().getLastMonthProductInsights(),
              emptyMessage: "No hay datos del mes anterior",
            ),
            const SizedBox(height: 32),

            const Text("Movimientos Recientes",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D))),
            const SizedBox(height: 16),
            const RecentMovementsSection(),
            const SizedBox(height: 32),

            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text("Alertas de Stock",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D)),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const StockAlertsSection(),
            const SizedBox(height: 32),

            const Text("Top Proveedores (IA)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D))),
            const SizedBox(height: 16),
            const ProviderRankingSection(),
            const SizedBox(height: 32),

            const Text("Estado de Inventario (IA)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1D))),
            const SizedBox(height: 16),
            const InventoryRiskSection(),
            const SizedBox(height: 32),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

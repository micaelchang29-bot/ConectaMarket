import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Control", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Chip(
              avatar: Icon(Icons.check_circle, color: Colors.green, size: 16),
              label: Text("Sincronizado", style: TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Resumen de hoy", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              // Grid de 2x2 para KPIs
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildMetricCard("Total Productos", "1,248", Icons.inventory_2, Colors.teal),
                  _buildMetricCard("Stock Crítico", "12", Icons.warning, Colors.red),
                  _buildMetricCard("Margen Hoy", "S/. 4,250", Icons.payments, Colors.orange),
                  _buildMetricCard("Demanda ML", "+15%", Icons.psychology, Colors.purple),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Ventas Recientes
              const Text("Ventas Recientes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildRecentSale("Ticket #A-482", "Hace 5 min", "S/. 85.00"),
              _buildRecentSale("Ticket #A-481", "Hace 22 min", "S/. 124.50"),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecentSale(String id, String time, String amount) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: const Icon(Icons.receipt_long),
      title: Text(id),
      subtitle: Text(time),
      trailing: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
    );
  }
}
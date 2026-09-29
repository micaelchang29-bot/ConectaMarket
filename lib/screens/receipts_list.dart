import 'package:conectamarket/models/receipts_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/receipt_service.dart';
import '../../widgets_global/base_card.dart';
import '../../widgets_global/header_bar.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final ReceiptService _service = ReceiptService();
  bool _mostrarCompras = false;

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<List<Receipt>>(
          stream: _service.receiptStream,
          initialData: _service.cachedReceipts,
          builder: (context, snapshot) {
            final count = snapshot.data?.where((r) => r.tipomovimiento == _mostrarCompras).length ?? 0;
            return HeaderBarWidget(
              title: "Comprobantes",
              badgeCount: count,
              showBackButton: false,
              actions: !_mostrarCompras
                  ? [
                      IconButton(
                        icon: const Icon(Icons.description_outlined),
                        tooltip: 'Exportar SUNAT',
                        onPressed: () => context.push('/sunat-export'),
                      ),
                    ]
                  : null,
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFE1E3E4), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _mostrarCompras = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: !_mostrarCompras ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                        child: Text("VENTAS", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: !_mostrarCompras ? const Color(0xFF0F6E56) : Colors.black54)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _mostrarCompras = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: _mostrarCompras ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                        child: Text("COMPRAS", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _mostrarCompras ? const Color(0xFF0F6E56) : Colors.black54)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Receipt>>(
                stream: _service.receiptStream,
                initialData: _service.cachedReceipts,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final receipts = snapshot.data!.where((r) => r.tipomovimiento == _mostrarCompras).toList();

                  if (receipts.isEmpty) {
                    return Center(child: Text("No hay ${_mostrarCompras ? 'compras' : 'ventas'} registradas."));
                  }

                  return ListView.builder(
                    itemCount: receipts.length,
                    itemBuilder: (context, index) {
                      final r = receipts[index];
                      return BaseCardWidget(
                        title: "Doc: ${r.id}", // O tu formato de serie-número
                        subtitle: "${_formatDate(r.fecha)} | ${r.providerId}",
                        priceOrStatus: "S/. ${r.total.toStringAsFixed(2)}",
                        onTap: () {
                          // Navegar a detalles/edición (pantalla única para crear/editar)
                          context.push('/receipt-form', extra: r);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F6E56),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => context.push('/receipt-form'),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
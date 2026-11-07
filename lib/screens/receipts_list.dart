import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/receipt_service.dart';
import '../../utils/validaciones.dart';
import '../../widgets_global/base_card.dart';
import '../../widgets_global/header_bar.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final ReceiptService _service = ReceiptService();
  final TextEditingController _busquedaController = TextEditingController();
  bool _mostrarCompras = false;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _service.refreshReceipts();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  List<MovimientoListado> _filtrar(List<MovimientoListado> todos) => todos
      .where((m) => m.receipt.tipomovimiento == _mostrarCompras && m.contieneProducto(_busqueda))
      .toList();

  String _resumenLineas(MovimientoListado m) {
    if (m.lineas.isEmpty) return 'Sin productos';
    final partes = m.lineas.take(3).map((l) => '${l.productNombre} × ${formatoCantidad(l.cantidad)}');
    final resto = m.lineas.length - 3;
    return partes.join(', ') + (resto > 0 ? ' y $resto más' : '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<List<MovimientoListado>>(
          stream: _service.receiptStream,
          initialData: _service.cachedMovements,
          builder: (context, snapshot) {
            final count = _filtrar(snapshot.data ?? []).length;
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _busquedaController,
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Filtrar por producto o SKU',
                  suffixIcon: _busqueda.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _busquedaController.clear();
                            setState(() => _busqueda = '');
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<MovimientoListado>>(
                stream: _service.receiptStream,
                initialData: _service.cachedMovements,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  // Ya vienen ordenados del más reciente al más antiguo
                  final movimientos = _filtrar(snapshot.data!);
                  final tipo = _mostrarCompras ? 'compras' : 'ventas';

                  if (movimientos.isEmpty) {
                    return Center(
                      child: Text(_busqueda.trim().isEmpty
                          ? "No hay $tipo registradas."
                          : "No hay $tipo con ese producto."),
                    );
                  }

                  return ListView.builder(
                    itemCount: movimientos.length,
                    itemBuilder: (context, index) {
                      final m = movimientos[index];
                      final r = m.receipt;
                      final tipoTexto = r.tipomovimiento ? 'Compra' : 'Venta';
                      final proveedor = r.tipomovimiento && (m.providerNombre ?? '').isNotEmpty
                          ? ' · ${m.providerNombre}'
                          : '';
                      return BaseCardWidget(
                        title: "${_formatDate(r.fecha)} · $tipoTexto$proveedor",
                        subtitle: "${_resumenLineas(m)}\nDoc: ${r.serie}-${r.id}",
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
        tooltip: 'Registrar movimiento',
        onPressed: () => context.push('/receipt-form'),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

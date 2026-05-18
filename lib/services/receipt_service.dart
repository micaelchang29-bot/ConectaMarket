import 'dart:async';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/product_service.dart';

class ReceiptService {
  final ReceiptRepository _repo = ReceiptRepository();
  
  // Stream para notificar a la UI cuando cambien los recibos
  final _receiptController = StreamController<List<Receipt>>.broadcast();
  Stream<List<Receipt>> get receiptStream => _receiptController.stream;

  ReceiptService() {
    refreshReceipts();
  }

  Future<void> refreshReceipts() async {
    final receipts = await _repo.getAllReceipts();
    _receiptController.add(receipts);
  }

  // Lógica de negocio: Registro completo de recibo + items
  Future<void> registerReceipt(Receipt receipt, List<ReceiptItem> items) async {
    // Aquí puedes añadir validaciones de negocio antes de persistir
    if (items.isEmpty) {
      throw Exception("No se puede registrar un recibo sin ítems.");
    }
    
    // Invocación al repositorio para la transacción atómica
    await _repo.saveFullReceipt(receipt, items);
    
    // Actualizar el estado de la UI
    await refreshReceipts();
    await ProductService().refreshProducts();
  }

  // Lógica para obtener el detalle completo de un recibo para mostrarlo
  Future<List<ReceiptItem>> getReceiptDetails(String receiptId) async {
    return await _repo.getItemsByReceiptId(receiptId);
  }

  double calculateTotalFromItems(List<ReceiptItem> items) {
    return items.fold(0.0, (sum, item) => sum + (item.cantidad * item.costoUnitario));
  }

  // Lógica de borrado
  Future<void> deleteReceipt(String id) async {
    await _repo.deleteReceipt(id);
    await refreshReceipts();
    // It shouldn't necessarily refresh products on delete, wait...
    // The prompt only asked for "cada vez que se registre un recibo (ya sea de forma manual o mediante el servicio de importación de CSV), se actualice automáticamente el stock"
  }

  void dispose() {
    _receiptController.close();
  }
}
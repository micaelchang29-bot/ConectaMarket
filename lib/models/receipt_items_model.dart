class ReceiptItem {
  final String id;
  final String receiptId;
  final String productId;
  final double cantidad;
  final double costoUnitario;

  ReceiptItem({
    required this.id, 
    required this.receiptId, 
    required this.productId, 
    required this.cantidad, 
    required this.costoUnitario
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'receipt_id': receiptId,
    'product_id': productId,
    'cantidad': cantidad,
    'costoUnitario': costoUnitario,
  };

  factory ReceiptItem.fromMap(Map<String, dynamic> map) => ReceiptItem(
    id: map['id'],
    receiptId: map['receipt_id'],
    productId: map['product_id'],
    cantidad: map['cantidad'],
    costoUnitario: map['costoUnitario'],
  );
}
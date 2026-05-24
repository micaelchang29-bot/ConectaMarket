class Receipt {
  final String id;
  final String? providerId;
  final String fecha;
  final double total;
  final bool tipomovimiento; // false=venta, true=compra
  final String serie;

  Receipt({
    required this.id,
    required this.providerId,
    required this.fecha,
    required this.total,
    this.tipomovimiento = false,
    this.serie = 'B001',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'provider_id': providerId,
    'fecha': fecha,
    'total': total,
    'tipomovimiento': tipomovimiento ? 1 : 0,
    'serie': serie,
  };

  factory Receipt.fromMap(Map<String, dynamic> map) => Receipt(
    id: map['id'],
    providerId: map['provider_id'] ?? '',
    fecha: map['fecha'],
    total: map['total'],
    tipomovimiento: (map['tipomovimiento'] ?? 0) == 1,
    serie: map['serie'] ?? 'B001',
  );
}
class Product {
  final String id;
  final String nombre;
  final double stock;
  final int umbralAlerta;
  final double precio;

  Product({
    required this.id,
    required this.nombre,
    this.stock = 0,
    this.umbralAlerta = 5,
    this.precio = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'stock': stock,
    'umbralAlerta': umbralAlerta,
    'precio': precio,
  };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'].toString(),
    nombre: map['nombre'].toString(),
    stock: (map['stock'] as num?)?.toDouble() ?? 0,
    umbralAlerta: (map['umbralAlerta'] as num?)?.toInt() ?? 5,
    precio: (map['precio'] as num?)?.toDouble() ?? 0,
  );
}

class Product {
  final String id;
  final String nombre;
  final double stock;
  final int umbralAlerta;
  /// Precio de venta al cliente (no es el costo de compra al proveedor).
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
    id: map['id'],
    nombre: map['nombre'],
    // SQLite puede devolver int o double segun el valor almacenado: se
    // normaliza a double para evitar errores de cast.
    stock: (map['stock'] as num).toDouble(),
    umbralAlerta: map['umbralAlerta'],
    precio: (map['precio'] as num?)?.toDouble() ?? 0,
  );
}
